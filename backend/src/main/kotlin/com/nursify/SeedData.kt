package com.nursify

import kotlinx.serialization.Serializable
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.json.Json
import org.jetbrains.exposed.sql.selectAll
import org.jetbrains.exposed.sql.transactions.transaction
import java.util.UUID

/**
 * Seeds the concept corpus from `resources/concepts.json` on an empty database.
 *
 * Content lives in JSON (not hand-written Kotlin) so it can scale to hundreds of
 * concepts and be reviewed/edited as data. Concepts reference each other by a
 * stable string `key` slug; UUIDs are generated at load time and related edges
 * are resolved from those slugs in a second pass. Still hand-curated placeholder
 * content standing in for the real AI-augmentation / corpus-ingestion pipeline
 * (SYSTEM_DESIGN.md roadmap Phases 5-6), not the actual curation process.
 *
 * Deleting the Postgres volume re-seeds on next boot (`docker compose down -v`);
 * a stale volume silently skips reseeding, since this only runs when empty.
 */
object SeedData {
    @Serializable
    private data class SeedFile(val concepts: List<ConceptSeed>)

    @Serializable
    private data class ConceptSeed(
        val key: String,
        val type: ConceptType,
        val name: String,
        val shortExplanation: String,
        val sections: ConceptSections = ConceptSections(),
        val tags: List<String> = emptyList(),
        val aliases: List<AliasSeed> = emptyList(),
        val related: List<String> = emptyList(),
        val pronunciation: String? = null,
        val assessment: AssessmentScoring? = null,
        val sourceCitation: String? = null
    )

    @Serializable
    private data class AliasSeed(val text: String, val type: String)

    private val json = Json { ignoreUnknownKeys = true }

    fun seedIfEmpty() {
        val alreadySeeded = transaction { Concepts.selectAll().limit(1).any() }
        if (alreadySeeded) return

        val text = javaClass.getResourceAsStream("/concepts.json")
            ?.bufferedReader()?.use { it.readText() }
            ?: error("concepts.json not found on the classpath")
        val seeds = json.decodeFromString<SeedFile>(text).concepts

        val duplicateKeys = seeds.groupingBy { it.key }.eachCount().filterValues { it > 1 }.keys
        require(duplicateKeys.isEmpty()) { "Duplicate concept keys in concepts.json: $duplicateKeys" }

        // Assign a UUID per slug up front so related edges can resolve regardless
        // of the order concepts appear in the file.
        val idByKey = seeds.associate { it.key to UUID.randomUUID() }

        seeds.forEach { seed ->
            val id = idByKey.getValue(seed.key)
            ConceptRepository.insert(
                id = id,
                type = seed.type,
                name = seed.name,
                shortExplanation = seed.shortExplanation,
                sections = seed.sections,
                tags = seed.tags,
                pronunciation = seed.pronunciation,
                assessment = seed.assessment,
                sourceCitation = seed.sourceCitation
            )
            seed.aliases.forEach { alias ->
                ConceptRepository.insertAlias(UUID.randomUUID(), id, alias.text, alias.type)
            }
        }

        // Second pass: related edges, now that every concept has an id.
        var edgeCount = 0
        seeds.forEach { seed ->
            val fromId = idByKey.getValue(seed.key)
            seed.related.forEach { targetKey ->
                val toId = idByKey[targetKey]
                if (toId == null) {
                    println("WARN: concept '${seed.key}' references unknown related key '$targetKey'")
                } else {
                    ConceptRepository.insertEdge(UUID.randomUUID(), fromId, toId, "related_to")
                    edgeCount++
                }
            }
        }

        println("Seeded ${seeds.size} concepts and $edgeCount related edges from concepts.json")
    }
}
