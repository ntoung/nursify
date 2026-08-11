package com.nursify

import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import org.jetbrains.exposed.sql.*
import org.jetbrains.exposed.sql.transactions.transaction
import java.time.Instant
import java.util.UUID

private val json = Json { ignoreUnknownKeys = true }

object ConceptRepository {

    fun insert(
        id: UUID,
        type: ConceptType,
        name: String,
        shortExplanation: String,
        sections: ConceptSections,
        tags: List<String>,
        sourceCitation: String?
    ) = transaction {
        Concepts.insert {
            it[Concepts.id] = id
            it[Concepts.type] = type.name
            it[Concepts.name] = name
            it[Concepts.shortExplanation] = shortExplanation
            it[Concepts.sectionsJson] = json.encodeToString(sections)
            it[Concepts.tagsJson] = json.encodeToString(tags)
            it[Concepts.sourceCitation] = sourceCitation
            it[Concepts.createdAt] = Instant.now()
        }
    }

    fun insertAlias(id: UUID, conceptId: UUID, aliasText: String, aliasType: String) = transaction {
        Aliases.insert {
            it[Aliases.id] = id
            it[Aliases.conceptId] = conceptId
            it[Aliases.aliasText] = aliasText
            it[Aliases.aliasType] = aliasType
        }
    }

    fun insertEdge(id: UUID, fromId: UUID, toId: UUID, edgeType: String) = transaction {
        ConceptEdges.insert {
            it[ConceptEdges.id] = id
            it[ConceptEdges.fromConceptId] = fromId
            it[ConceptEdges.toConceptId] = toId
            it[ConceptEdges.edgeType] = edgeType
            it[ConceptEdges.weight] = 1
            it[ConceptEdges.createdAt] = Instant.now()
            it[ConceptEdges.lastReinforcedAt] = Instant.now()
        }
    }

    fun findById(id: UUID): ConceptDto? = transaction {
        val row = Concepts.select { Concepts.id eq id }.singleOrNull() ?: return@transaction null
        rowToDto(row)
    }

    // Case-insensitive matching done in Kotlin rather than via SQL LOWER()/LIKE
    // for now — fine at this data scale, and sidesteps Exposed DSL functions
    // that vary across versions. Revisit with real SQL text search once the
    // corpus grows (see SYSTEM_DESIGN.md — trigram index was the intended design).
    fun findByNameIgnoreCase(name: String): ConceptDto? = transaction {
        val row = Concepts.selectAll().firstOrNull { it[Concepts.name].equals(name, ignoreCase = true) }
            ?: return@transaction null
        rowToDto(row)
    }

    fun search(query: String): List<ConceptSummaryDto> = transaction {
        val lowerQuery = query.lowercase()
        val matchingConceptIds = Aliases.selectAll()
            .filter { it[Aliases.aliasText].lowercase().contains(lowerQuery) }
            .map { it[Aliases.conceptId] }
            .toSet()

        Concepts.selectAll()
            .filter { it[Concepts.name].lowercase().contains(lowerQuery) || it[Concepts.id] in matchingConceptIds }
            .map { row ->
                val sections = json.decodeFromString<ConceptSections>(row[Concepts.sectionsJson])
                ConceptSummaryDto(
                    id = row[Concepts.id].toString(),
                    type = ConceptType.valueOf(row[Concepts.type]),
                    name = row[Concepts.name],
                    sideEffectsPreview = sections.sideEffects
                )
            }
    }

    fun byCategory(type: ConceptType): List<ConceptSummaryDto> = transaction {
        Concepts.select { Concepts.type eq type.name }.map { row ->
            ConceptSummaryDto(
                id = row[Concepts.id].toString(),
                type = ConceptType.valueOf(row[Concepts.type]),
                name = row[Concepts.name]
            )
        }
    }

    private fun rowToDto(row: ResultRow): ConceptDto {
        val id = row[Concepts.id]
        val sections = json.decodeFromString<ConceptSections>(row[Concepts.sectionsJson])
        val tags = json.decodeFromString<List<String>>(row[Concepts.tagsJson])
        val aliases = Aliases.select { Aliases.conceptId eq id }.map {
            AliasDto(id = it[Aliases.id].toString(), text = it[Aliases.aliasText], type = it[Aliases.aliasType])
        }
        val relatedIds = ConceptEdges.select { ConceptEdges.fromConceptId eq id }.map {
            it[ConceptEdges.toConceptId].toString()
        }
        return ConceptDto(
            id = id.toString(),
            type = ConceptType.valueOf(row[Concepts.type]),
            name = row[Concepts.name],
            shortExplanation = row[Concepts.shortExplanation],
            sections = sections,
            tags = tags,
            aliases = aliases,
            relatedConceptIds = relatedIds,
            sourceCitation = row[Concepts.sourceCitation]
        )
    }
}

object NoteRepository {
    fun create(request: NoteCreateRequest): NoteDto = transaction {
        val id = UUID.randomUUID()
        val now = Instant.now()
        Notes.insert {
            it[Notes.id] = id
            it[Notes.transcript] = request.transcript
            it[Notes.device] = request.device
            it[Notes.phiReviewed] = request.phiReviewed
            it[Notes.createdAt] = now
        }
        // TODO: enqueue async AI augmentation (transcript cleanup -> concept
        // extraction -> dedup embedding -> RAG explanation -> edge creation).
        // Not implemented — needs a real LLM/embeddings integration.
        // See SYSTEM_DESIGN.md "AI/ML pipeline architecture".
        NoteDto(
            id = id.toString(),
            transcript = request.transcript,
            device = request.device,
            phiReviewed = request.phiReviewed,
            createdAt = now.toString()
        )
    }
}

object SearchHistoryRepository {
    // Note: doesn't dedupe a repeat view of the same concept into one row yet
    // (the iOS mock layer does this client-side) — `all()` orders by
    // viewedAt DESC so the latest view still surfaces first either way.
    // Follow-up: move old entries aside instead of leaving duplicates.
    fun record(conceptId: UUID): SearchHistoryDto = transaction {
        val id = UUID.randomUUID()
        val now = Instant.now()
        SearchHistoryEntries.insert {
            it[SearchHistoryEntries.id] = id
            it[SearchHistoryEntries.conceptId] = conceptId
            it[SearchHistoryEntries.viewedAt] = now
        }
        val concept = ConceptRepository.findById(conceptId)
        SearchHistoryDto(
            id = id.toString(),
            conceptId = conceptId.toString(),
            conceptName = concept?.name ?: "Unknown",
            type = concept?.type ?: ConceptType.MEDICATION,
            viewedAt = now.toString()
        )
    }

    fun all(): List<SearchHistoryDto> = transaction {
        SearchHistoryEntries.selectAll().orderBy(SearchHistoryEntries.viewedAt to SortOrder.DESC).map { row ->
            val concept = ConceptRepository.findById(row[SearchHistoryEntries.conceptId])
            SearchHistoryDto(
                id = row[SearchHistoryEntries.id].toString(),
                conceptId = row[SearchHistoryEntries.conceptId].toString(),
                conceptName = concept?.name ?: "Unknown",
                type = concept?.type ?: ConceptType.MEDICATION,
                viewedAt = row[SearchHistoryEntries.viewedAt].toString()
            )
        }
    }

    fun clear() = transaction {
        SearchHistoryEntries.deleteAll()
    }
}
