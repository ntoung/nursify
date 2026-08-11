package com.nursify.shared.db

import app.cash.sqldelight.db.SqlDriver

/**
 * Platform-specific SQLite driver creation — the one genuinely necessary
 * expect/actual in this module. Implementations: DatabaseDriverFactory.jvm.kt
 * (verified — compiles and runs in Docker) and DatabaseDriverFactory.ios.kt
 * (written but unverified — Kotlin/Native's iOS targets only link on macOS).
 */
expect class DatabaseDriverFactory {
    fun createDriver(): SqlDriver
}

fun createDatabase(factory: DatabaseDriverFactory): NursifyDatabase {
    return NursifyDatabase(factory.createDriver())
}
