package com.nursify.shared.db

import app.cash.sqldelight.db.SqlDriver
import app.cash.sqldelight.driver.jdbc.sqlite.JdbcSqliteDriver

/**
 * JVM implementation — exists primarily so this module's database layer can
 * be compiled and exercised without a Mac (see build.gradle.kts comment on
 * the jvm() target). Not what iOS actually uses at runtime.
 */
actual class DatabaseDriverFactory {
    actual fun createDriver(): SqlDriver {
        val driver: SqlDriver = JdbcSqliteDriver(JdbcSqliteDriver.IN_MEMORY)
        NursifyDatabase.Schema.create(driver)
        return driver
    }
}
