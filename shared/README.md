# shared

Kotlin Multiplatform module per `REQUIREMENTS.md`'s "Shared logic" row and `SYSTEM_DESIGN.md`'s sync/data-model sections. Holds the client-side data models, the API client, and local SQLite (SQLDelight) storage — the pieces genuinely worth sharing between iOS and a future Android app, rather than writing twice.

## What's verified vs. not

**Verified** — built and run inside Docker (`gradle:8.7-jdk21`), against the JVM target:
- `commonMain` compiles clean (models, `ApiClient`, SQLDelight schema, `DatabaseDriverFactory` expect declaration).
- `gradle jvmTest` — 3 real runtime tests, all passing:
  - SQLDelight insert/read round-trip against an in-memory SQLite DB.
  - `ApiClient.searchConcepts` and `ApiClient.chartLookup` making live HTTP calls to the actual backend (`../backend`) running in a sibling container on the same Docker network — including the "medication not found" case.

**Not verified — cannot be, from this environment**: the `iosArm64`/`iosSimulatorArm64` targets. Running `gradle wrapper` here printed, verbatim:

```
w: The following Kotlin/Native targets cannot be built on this machine and are disabled:
iosArm64, iosSimulatorArm64
```

This isn't a bug to fix — Kotlin/Native's Apple targets only link on macOS (they need Apple's linker/frameworks). `gradle.properties` sets `kotlin.native.ignoreDisabledTargets=true` so the JVM-target build doesn't fail because of it. **First thing to do on a Mac: run `./gradlew compileKotlinIosArm64 compileKotlinIosSimulatorArm64`** and fix whatever surfaces — `DatabaseDriverFactory.ios.kt` in particular follows the standard SQLDelight/Kotlin-Native pattern but has never actually compiled.

## Structure

```
shared/
  src/
    commonMain/
      kotlin/.../model/Models.kt       # Concept, ConceptType, Alias, Note DTOs, etc.
      kotlin/.../network/ApiClient.kt  # Ktor Client — talks to ../backend
      kotlin/.../db/DatabaseDriverFactory.kt  # expect class
      sqldelight/.../db/ConceptCache.sq   # local read cache
      sqldelight/.../db/PendingNote.sq    # offline capture outbox
    jvmMain/     # DatabaseDriverFactory actual (verified) — JDBC/in-memory SQLite
    iosMain/     # DatabaseDriverFactory actual (unverified) — NativeSqliteDriver
    jvmTest/     # SharedModuleSmokeTest.kt
```

## Not yet done

- **Not wired into `iosApp`.** The SwiftUI app still has its own hand-written Swift models (`iosApp/iosApp/Models.swift`) and no networking — it runs entirely on in-memory mock data. Actually consuming this module means building it as an `.xcframework` and adding it as an Xcode dependency, which needs Xcode/macOS. Until that happens, this module and the iOS app are two separate, currently-unconnected pieces that happen to model the same things.
- **No Android target.** Trivial to add (`androidTarget()`) once that roadmap phase starts — not added preemptively since there's no Android app to consume it yet.
- **`PendingNote` outbox has no consumer yet.** The table and queries exist; nothing calls `ApiClient.createNote()` from a background sync loop yet.
- **`ConceptCache` has no cache-population/invalidation policy yet** — the queries exist, nothing decides when to write to or read from the cache versus hitting the network directly.
