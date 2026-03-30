---
layout: post
title:  Implement your own in-house Crashlytics for Android
date:   2020-04-23 23:18:12 +0700
categories: android crashlytics
---

## Why

For years, Crashlytics by Fabric was the gold standard for mobile crash reporting. It was fast, reliable, deeply integrated with Android tooling, and free. Teams adopted it without hesitation, and it became load-bearing infrastructure for mobile development at companies of every size.

Then Google acquired Fabric.

The migration from Fabric Crashlytics to Firebase Crashlytics was manageable for many teams, but it immediately raised a set of questions we could not get clear answers to. Firebase tools, as a rule, depend on Google Play Services — a hard requirement that excludes Huawei devices running HMS (Huawei Mobile Services) and the Chinese Android ecosystem more broadly, where GMS is not available. China represented a significant portion of our user base, and the prospect of running two parallel crash reporting systems — one for GMS markets, one for HMS — was operationally unappealing.

Beyond the immediate practicalities, the acquisition surfaced a deeper concern: our crash reporting infrastructure was entirely controlled by a third party whose roadmap we could not influence and whose business decisions could affect our operations at any time. We had already lived through one such decision.

These concerns, taken together, pointed toward building our own crash reporting system.

## The Strategic Case for Ownership

The defensive argument for building in-house crash reporting — vendor independence, market coverage — was sufficient on its own. But the more compelling argument was what becomes possible when you own the data pipeline end to end.

Crash data contains rich, structured information: the file, the class, the line number, the thread state, the stack at the moment of failure. In our system, we could connect this information directly to our existing infrastructure:

**Automated incident response**: Every crash has a filename and line number. Our codebase is managed in Git. Using `git blame`, we can map any crash directly to the commit that introduced the failing code and the team responsible for it. An automated system can open a ticket, notify the relevant team, or even trigger a rollback — without human intervention.

**Feature flag integration**: Our release process is built around feature flags and A/B tests. A new feature is always behind a flag before it is fully rolled out. When a crash occurs in a flagged feature, we can identify the flag from the source location and automatically disable it, preventing further exposure to the crashing code path. This closes the loop from crash detection to crash mitigation without a human on-call cycle.

**Developer attribution and accountability**: The `git blame` pipeline also enables precise attribution. The system can automatically notify the developer whose commit introduced a crash within minutes of the first occurrence in production — far faster than any manual triage process.

**ML-assisted root cause analysis**: With full ownership of crash data and the infrastructure to process it, training models to identify crash-prone patterns, predict regression risk from code changes, or cluster related crashes by root cause becomes tractable. The vision of receiving a suggested fix within minutes of a crash is not science fiction; it requires data ownership as a prerequisite.

To be fair, some of this is achievable using Firebase Crashlytics data exported to BigQuery. But BigQuery export introduces latency measured in hours, not seconds. For real-time incident response, that latency is disqualifying. And the China market problem remains regardless.

## How: The Android Client

The Android client side of a crash reporting system is simpler than the backend. The backend handles the hard problems: deobfuscating stack traces from ProGuard/R8 symbol maps, deduplication, aggregation, alerting, and visualization. The Android client has one job: reliably capture exceptions and ensure they reach the backend.

### Registering the Exception Handler

Java and Android provide a standard mechanism for catching unhandled exceptions: `Thread.setDefaultUncaughtExceptionHandler`. This handler is invoked for any exception that propagates to the top of a thread's call stack without being caught:

```kotlin
val defaultHandler = Thread.getDefaultUncaughtExceptionHandler()

Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
    try {
        crashLogger.log(thread, throwable)
    } finally {
        defaultHandler.uncaughtHandler(thread, throwable)
    }
}
```

Two details here are critical for correctness:

First, save the existing default handler before replacing it, and call it in a `finally` block after your own handler runs. The default handler is responsible for terminating the process, producing the system crash dialog, and notifying the Android runtime. If you replace it without delegating to it, the process will not terminate normally, producing strange behavior and potentially causing subsequent launches to appear in a non-crashed state.

Second, the `finally` block ensures the default handler is called even if your own crash logging throws an exception — which is possible if the application is in a severely degraded state.

This setup code can be placed in `Application#onCreate()`. For applications where early-lifecycle crashes are a concern, a `ContentProvider` initialized before `Application#onCreate()` can be used to register the handler even earlier in the process startup sequence.

### Why You Cannot Make a Network Call Immediately

The instinct when catching a crash is to send it to the backend immediately. This does not work reliably, for three reasons:

1. **The process is about to die.** The uncaught exception handler runs immediately before process termination. Any async work started in the handler — a network request, for example — will be killed before it completes.
2. **The main thread may be unresponsive.** If the crash occurred on the main thread, the UI event loop is no longer running. Network libraries that dispatch callbacks to the main thread will silently fail.
3. **The heap may be exhausted.** Some crashes are caused by `OutOfMemoryError`. Attempting to allocate new objects for a network request in this state will fail immediately.

The correct pattern is a two-phase approach: save the crash locally during the crash handler, then send it to the backend on the next application launch, after the process has restarted cleanly and the network stack is fully operational.

```kotlin
interface CrashLogger {
    fun log(thread: Thread, throwable: Throwable)
}

class FileCrashLogger : CrashLogger { ... }
class SqliteCrashLogger : CrashLogger { ... }
```

**FileCrashLogger** writes the crash as plain text to a file. It has minimal dependencies and is unlikely to fail during a crash — even if the application heap is under pressure, writing a small file to disk does not require significant allocation.

**SqliteCrashLogger** writes to a SQLite database. This enables structured queries on crash history (useful if you want to deduplicate on the client), atomic writes, and easier enumeration of pending crashes. The trade-off is that SQLite itself is a complex system; if the crash was caused by database corruption or if SQLite's own thread pool is in a bad state, the logger may fail. For maximum reliability in crash scenarios, file storage is safer.

### Capturing the Stack Trace

Converting a `Throwable` to a string for storage is straightforward:

```kotlin
val sw = StringWriter()
throwable.printStackTrace(PrintWriter(sw))
val str = sw.toString()
```

For comprehensive diagnostics, capturing the state of all threads at the moment of the crash can be invaluable — particularly for diagnosing deadlocks, thread contention, or crashes caused by interactions between background work and the main thread:

```kotlin
val stackTraces = mutableMapOf<String, String>()

Thread.getAllStackTraces().forEach { (thread, stackTrace) ->
    val stringBuilder = StringBuilder(thread.name)

    stackTrace.forEach { element ->
        stringBuilder
            .append("\n\tat ")
            .append(element.className)
            .append('.')
            .append(element.methodName)
            .append('(')
            .append(element.fileName)
            .append(':')
            .append(element.lineNumber)
            .append(')')
    }

    stackTraces[thread.name] = stringBuilder.toString()
}
```

For use cases where only the crash origin matters — for example, to look up the associated feature flag or git blame entry — the minimal form is sufficient:

```kotlin
throwable.stackTrace?.firstOrNull()?.let { crash ->
    crash.fileName // sample.kt
    crash.lineNumber // 42
    crash.className // Sample
}
```

One production edge case worth handling: `Throwable#getStackTrace()` can return an empty array. This occurs when the `Throwable` was constructed with `writableStackTrace = false` — a legitimate optimization sometimes used for exception types where stack traces are never needed (certain `ArithmeticException` subclasses, for example). A null or empty check guards against `firstOrNull()` returning null in this case.

## What This System Does Not Cover

This article covers the Android client component. A production-ready system requires substantially more:

- **Symbol map management**: ProGuard and R8 obfuscate class and method names in release builds. The backend must maintain a mapping from obfuscated names back to source symbols, keyed by build version, and apply it to every incoming crash report.
- **Multi-process apps**: Android applications can run in multiple processes (services, remote processes, etc.). The uncaught exception handler must be registered separately in each process. A `ContentProvider` that performs registration in its `onCreate` is a clean way to ensure this happens automatically.
- **JNI crashes**: Native crashes in JNI code are not captured by `Thread.setDefaultUncaughtExceptionHandler`. Native crash handling requires separate mechanisms (signal handlers, breakpad, or Firebase Crashlytics's native SDK).
- **ANR detection**: Application Not Responding errors are a distinct failure mode from exceptions. Detecting them requires a separate watchdog mechanism — typically a background thread that monitors main thread responsiveness.

The client-side implementation described here is intentionally minimal — a foundation on which a full crash reporting pipeline can be built. The interesting and difficult problems live in the backend and the integration layer, but they all depend on this foundation being correct and reliable.

*NOTE: This code is a sample. If you want to make a production-ready system, there are many additional considerations beyond what is covered here.*
