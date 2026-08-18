package com.nursify

import com.zaxxer.hikari.HikariConfig
import com.zaxxer.hikari.HikariDataSource
import org.jetbrains.exposed.sql.Database as ExposedDatabase
import org.jetbrains.exposed.sql.SchemaUtils
import org.jetbrains.exposed.sql.transactions.transaction

object Database {
    fun init() {
        val url = System.getenv("DATABASE_URL") ?: "jdbc:postgresql://localhost:5432/nursify"
        val user = System.getenv("DATABASE_USER") ?: "nursify"
        val password = System.getenv("DATABASE_PASSWORD") ?: "nursify"

        val config = HikariConfig().apply {
            jdbcUrl = url
            username = user
            this.password = password
            driverClassName = "org.postgresql.Driver"
            maximumPoolSize = 10
        }
        val dataSource = HikariDataSource(config)
        ExposedDatabase.connect(dataSource)

        transaction {
            SchemaUtils.create(
                Concepts,
                Aliases,
                ConceptEdges,
                Notes,
                NoteMentions,
                ReviewSchedules,
                Reports
            )
        }
    }
}
