---
layout: post
title:  Exclude properties from toString() of Kotlin data class (Sekret appx.)
date:   2019-08-13 15:00:00 +0700
categories: kotlin data-class
---

*This post describes how to remove class properties from the `toString()` method manually if you prefer not to use the [Sekret]({% post_url 2019-08-13-sekret %}) compiler plugin.*

---

Kotlin's data class `toString` is generated automatically to include every property defined in the primary constructor. This is convenient for debugging but problematic when some of those properties contain sensitive data — passwords, tokens, PII — that must not appear in logs, crash reports, or analytics pipelines.

There is no built-in Kotlin mechanism to exclude a specific field from the generated `toString` while keeping it in `equals`, `hashCode`, and `copy`. The language does not (yet) offer an annotation equivalent to `@Transient` for serialization. The approaches below represent the practical trade-offs available in pure Kotlin, each with distinct implications for class semantics, mutability, and maintainability.

### 1. Override toString() yourself

The most straightforward approach is to manually override `toString` in the data class body:

```kotlin
data class Data(
    val login: String,
    val password: String
) {
    override fun toString() = ""
}
```

**What this solves:** Prevents `password` from appearing in log output immediately and without adding any new types or indirection.

**What this breaks:** You have opted out of the entire auto-generated `toString`. If you want other properties to appear — `login`, for example — you must now construct the string manually. Every time you add a new property to the class, you must remember to update the override. If you forget, the new property will silently never appear in logs, which is often exactly the wrong behavior. The maintenance burden grows proportionally with the class size.

It is also worth noting that overriding `toString` only affects logging output. The `password` field is still fully included in `equals`, `hashCode`, `copy`, and destructuring (`componentN`). Those semantics remain intact — which is usually what you want, but is worth understanding clearly.

**When to use this:** Acceptable for small, stable classes that are unlikely to grow, where the only goal is to suppress all output in logs entirely. For anything more nuanced, the maintenance cost is not worth it.

### 2. Define the property outside the primary constructor

Kotlin data class semantics only apply to properties declared in the primary constructor. Properties declared in the class body are excluded from `toString`, `equals`, `hashCode`, `copy`, and all `componentN` functions:

```kotlin
data class Data(
    val login: String
) {
    var password: String
}

// Usage - instantiate and set
val data = Data("login")
data.password = "password"
```

**What this solves:** `password` is completely invisible to all auto-generated data class functions. It will never appear in `toString`, and it does not participate in equality comparisons or `copy()`.

**What this breaks:** The exclusion from `equals` and `hashCode` changes the object's identity semantics in a fundamental way. Two `Data` instances with the same `login` but different passwords are considered equal by the data class. `copy()` will produce a new instance without `password` copied — setting it to an uninitialized state. If `Data` objects are used as keys in maps or stored in sets, or if `copy()` is used to produce modified versions, these behaviors may produce subtle bugs.

There is also a forced mutability problem: defining a field in the class body requires it to be `var` (unless it has a default value). This breaks the immutability of the data class, which is often a core reason for choosing data classes in the first place. Initialization requires a two-step process — construct then set — which makes the class impossible to use in most functional pipelines.

**When to use this:** When the property genuinely has no place in equality comparisons or copying — for example, a lazily-computed cache value or a transient UI handle. It is a poor fit for actual data fields like passwords.

### 3. Use a wrapper class

A more principled approach is to wrap the sensitive value in a type whose `toString` returns an empty string or a redaction marker:

```kotlin
// Wrapper
class Secret<T>(val data: T) {
    override fun toString() = ""
}

data class Data(
    val login: String,
    val password: Secret<String>
)

// Usage - create / read
val data = Data("login", Secret("password"))
data.password.data
```

**What this solves:** `password` participates fully in all data class semantics — it is included in `equals`, `hashCode`, `copy`, and destructuring. The only thing suppressed is the value in `toString`. The original data class structure is preserved, and you get correct `copy()` behavior.

There is an additional, underappreciated benefit: the type system now makes the sensitivity of this field explicit. When a developer reads the class definition, `Secret<String>` signals immediately that this field requires careful handling. It serves as inline documentation that persists through refactors. Code review tools and static analysis can potentially flag any access to `.data` on a `Secret` instance to ensure it is not being logged unsafely.

**What this breaks:** Accessing the underlying value requires an extra `.data` dereference. This creates a small but consistent friction at every use site. Some developers view this as a drawback; others view it as a feature — friction that makes accidental logging slightly harder. The type is also not directly comparable to a plain `String`, which may complicate integration with serialization libraries or frameworks that expect a specific type.

A production-quality `Secret<T>` implementation should also override `equals` and `hashCode` to delegate to the wrapped value, ensuring that `Data("login", Secret("a")) != Data("login", Secret("b"))` works as expected.

**When to use this:** The strongest of the manual options. The type-level signal, correct data class semantics, and composability make this a good pattern for codebases that need systematic protection without a compiler plugin.

### 4. Do not use data classes

Sometimes the right answer is to step back and ask whether a data class was the appropriate choice at all:

```kotlin
class Data(
    val login: String,
    val password: String
)
```

A regular class gives you complete control over `toString`, `equals`, `hashCode`, and `copy` (or the absence of `copy`). There is no auto-generated behavior to work around.

**When to use this:** When the class does not actually need the semantics of a data class — no structural equality comparisons, no destructuring, no `copy()` calls. If the class is used only as a container passed through a pipeline and never compared or copied, the data class overhead (and the `toString` problem) may be unnecessary. Choosing a regular class in this case is not a workaround — it is the appropriate design decision.

---

## The Underlying Problem with All Four Approaches

Each of the options above requires the developer to actively remember to protect every sensitive field, in every class, at every point in the class's lifetime. They are all opt-in: the default behavior is to expose everything.

This creates a systematic risk. As classes evolve — new fields added, existing fields renamed — the protection must be consciously re-applied. A developer unfamiliar with the codebase's conventions, or working under time pressure, will produce a class that leaks by default.

The [Sekret]({% post_url 2019-08-13-sekret %}) compiler plugin addresses this at the root: protection is declared once per field with an annotation, and the compiler enforces it permanently. The annotation travels with the field through refactors, class renames, and codebase migrations. No manual `toString` override to maintain, no wrapper type to thread through the codebase — just a single annotation that expresses intent and delegates enforcement to the compiler.
