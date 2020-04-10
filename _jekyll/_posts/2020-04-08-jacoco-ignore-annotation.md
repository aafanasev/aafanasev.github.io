---
layout: post
title:  Filter out classes from JaCoCo report using annotaitons
date:   2020-04-10 16:26:00 +0700
categories: kotlin jacoco
---

{:refdef: style="text-align: center;"}
![JaCoCo code coverate report with Generated annotation](/assets/img/jacoco-code-coverage.png)
{: refdef}

## Story

(can be skipped)

Long time ago in our company, we decided to use code coverage level as one of the must requirements to merge PR into `develop` branch. We have automated merge bot which automatically merges if the branch meets all requirements. We came up with magic number `80%`, so every new/modified class must be covered by Unit tests as minimum 80%.

*There are many discussions about code coverage, 80%, JaCoCo, etc. This article is not about that.*

We were happy with this requirement. Teams started to write more testable code, think about architecture, app stability went up, etc. We understood it's impossible to cover all classes in our project, there are many reasons: legacy code (lots of LOC need to be refactored; Business just won't give time for that; "if it works don't touch!"), auto-generated code (why we need to test 3rd party libs, etc), some code frankly does not need to be tested. Therefore, we need a way to filter out specific classes from JaCoCo report and allow devs/tools to merge branches.

Even more problems started to appear after moving to Kotlin from Java. JaCoCo, as you may know, works as java-agent with java bytecode only. Kotlin is a great language which reduced boilerplate code a lot but underhood the hood (in case of JVM) it generates a lot of helper methods, lines of code. For example, data class becomes a class with auto-generated methods such as `equals`, `hashCode`, `component1`, etc; even one line of code like `s?.foo()` or just `s.foo()` (where `s` defined as `lateinit`) will have 1 `if` in the generated code. Obviuosly, we do not have to test the generated code. All this generated stuff dramatically decreased our code coverage numbers. Keep in mind, those numbers can be KPI for some teams (yeah, bloody enterprise...).

## Ideas

#### 1. Custom Gradle task with filter

This way is suitable for most teams. Create a task using `JacocoReport` and make it depend on `test` &amp; `generate report` tasks. Then define an array of classes that you want to ignore and pass it as `excludes` parameter of `fileTree` method.

```groovy
task jacocoTestReport(type: JacocoReport, dependsOn: [...]) {
    // filter rules
    def fileFilter = [
        '**/R.class',
        '**/R$*.class',
    ]

    def debugTree = fileTree(
        dir: "${buildDir}/intermediates/classes/debug", 
        excludes: fileFilter // <-- exclude listed classes
    )

    classDirectories = files([debugTree])

    // some code...
}
```

Pros:
- All ignored classes in 1 place

Cons:
- Easy to make a mistake. One day we have found a rule `**/R*.class` which supposed to filter out `R` class & nested classes (known by every Android developer) but JaCoCo was ignoring all classes started with `R` :)

#### 2. Annotation processor

Since all developers are lazy and we rather spend 1 day on automating routine job, my colleague came up with Annotation processor approach. He has created `NoCoverage` annotation and a processor which saves all annotated classes into a file. Later on the file was used by `jacocoTestReport` instead of `fileFilter` array. Genius!

Pros:
- Automation!
- Less manual work

Cons:
- APT is not suitable for this kind of jobs. Especially, if it doesn't support incremental processing and you have many modules.

#### 3. Forked Kotlin compiler

We found out that JaCoCo team in order to support Lombok added a filter which doesn't count coverage of `@Generated` annotated classes/methods. Without thinking twice, another colleague has forked Kotlin compiler (!) and modified so it started adding `Generated` annotation to every generated method. Of course, we haven't used this approach in prod code. Later, JaCoCo added `@kotlin.Metadata` filter too.

... and finally!

## Solution: Annotation + Kotlin typealias

While investigating JaCoCo code I found that they changed `AnnotationGeneratedFilter` behaviour. Now instead of checking exact match of annotation name it just should [contain](https://github.com/jacoco/jacoco/blob/6bcce6972b8939d7925c4b4d3df785d9a7b00007/org.jacoco.core/src/org/jacoco/core/internal/analysis/filter/AnnotationGeneratedFilter.java#L51) `Generated` word. It means we can create any annotation with proper name and JaCoCo will automatically ignore all annotated classes and methods. 

In case of Kotlin you can use `typealias` to make your code more readable:

```kotlin
@Retention(AnnotationRetention.BINARY)
annotation class NoCoverageGenerated

typealias NoCoverage = NoCoverageGenerated

// or just

typealias NoCoverage = Generated // from javax.annotations package
```

Pros:
- Easy to use
- No code generation

Cons:
- Workaround. From JaCoCo Wiki: 
  > Remark: A Generated annotation should only be used for code actually generated by compilers or tools, never for manual exclusion.
- Useless annotation in prod code. But if you use code obfuscator such as Proguard/Dexguard/R8 (Android) that annotation will be cut out.