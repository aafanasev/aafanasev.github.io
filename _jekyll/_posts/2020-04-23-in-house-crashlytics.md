---
layout: post
title:  Implement your own in-house Crashlytics for Android
date:   2020-04-23 23:18:12 +0700
categories: android crashlytics
---

## Why

We've been using Crashlytics by Fabric for many years in our company. When Google have acquired Fabric and asked Crashlytics users to migrate to Firebase, we started thinking what can happen with Crashlytics: will it require Play Services as other Firebase tools do (e.g. Firebase App Distribution), will it work in China (huge market for us), etc.

Actually, above situation was one of many reasons why we decided to implement our own crash catcher system. Having crash information in your own database opens a lot of opportunities. We do a lot of A/B testing, all new features are covered by feature flags, remote configurations, etc. Using the crash info such as a filename, line number we can identify which feature/experiment causes this crash and automatically & remotely turn it off. This is just one use case. We can identify what team or developer this file or change belongs to using `git blame` and automatically ~~fire~~ notify them. Or even train ML models using all collected crashes. Let's just imagine, you got a crash and in a minite you received an email with PR that fixes the crash. Infinite opportunities.

To be fair, we can acrhieve all things we imagined using Google's BigQuery to export data from Firebase Crashlytics. But it's not real-time and not free. Other libraries we didn't like for one reason or another. We'd like to have 100% control.

## How

Android (excluding JNI) is the easiest part of this huge system. Backend will be deobfuscating (proguard, R8), saving, analyzing, showing, notifying, etc. On client side, we should just catch exceptions and send them to the backend side. In order to do that, we must use `setDefaultUncaughtExceptionHandler` method of `Thread` class. Do not forget to "save" previously set handler and pass caught data to it once we're done. Otherwise, Android won't kill the process.

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

`CrashLogger` interface might look like this. We have to save stacktrace somewhere locally and next app launch it's need to be sent to the server. We can't immediatelly make network call once we caught a crash because it will be too slow.

```kotlin
interface CrashLogger {
    fun log(thread: Thread, throwable: Throwable)
}

class FileCrashLogger : CrashLogger { ... }
class SqliteCrashLogger : CrashLogger { ... }
```

Easy way of converting throwable stacktrace to string:

```kotlin 
val sw = StringWriter()
throwable.printStackTrace(PrintWriter(sw))
val str = sw.toString()
```

If you want to get all stacktraces from all threads:

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

*NOTE: This code is just a sample. If you really want to create your own Crashlytics and make it production ready there are many things to keep in mind, at least Multi processes, JNI (if you use it).*