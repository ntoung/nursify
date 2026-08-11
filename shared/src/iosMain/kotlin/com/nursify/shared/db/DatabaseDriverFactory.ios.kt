package com.nursify.shared.db

import app.cash.sqldelight.db.SqlDriver
import app.cash.sqldelight.driver.native.NativeSqliteDriver

/**
 * iOS implementation — standard SQLDelight/Kotlin-Native pattern, but
 * UNVERIFIED: Kotlin/Native's Apple targets only link on macOS, and this
 * environment has no Xcode. Compile this on a Mac before trusting it.
 */
actual class DatabaseDriverFactory {
    actual fun createDriver(): SqlDriver {
        return NativeSqliteDriver(NursifyDatabase.Schema, "nursify.db")
    }
}
