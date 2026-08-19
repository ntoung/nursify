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
        pronunciation: String?,
        assessment: AssessmentScoring?,
        sourceCitation: String?
    ) = transaction {
        Concepts.insert {
            it[Concepts.id] = id
            it[Concepts.type] = type.name
            it[Concepts.name] = name
            it[Concepts.shortExplanation] = shortExplanation
            it[Concepts.sectionsJson] = json.encodeToString(sections)
            it[Concepts.tagsJson] = json.encodeToString(tags)
            it[Concepts.pronunciation] = pronunciation
            it[Concepts.assessmentJson] = assessment?.let { a -> json.encodeToString(a) }
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

    /**
     * Resolve a term to a concept by exact (case-insensitive) name first, then
     * by any exact alias — so chart lookup matches brand names and common
     * abbreviations too (e.g. "Lasix" or "ASA" -> the curated concept), not
     * just the canonical name.
     */
    fun findByNameOrAliasIgnoreCase(term: String): ConceptDto? = transaction {
        findByNameIgnoreCase(term)?.let { return@transaction it }
        val aliasRow = Aliases.selectAll()
            .firstOrNull { it[Aliases.aliasText].equals(term, ignoreCase = true) }
            ?: return@transaction null
        Concepts.select { Concepts.id eq aliasRow[Aliases.conceptId] }.singleOrNull()?.let { rowToDto(it) }
    }

    // Relevance-ranked, typo-tolerant search over the full corpus. Scoring
    // lives in ConceptSearch, kept in lock-step with the iOS offline library so
    // the API and the app agree. `findAll()` already carries names, aliases,
    // and tags, so ranking is plain in-memory work at this corpus scale (see
    // SYSTEM_DESIGN.md for the eventual SQL trigram/index plan).
    fun search(query: String): List<ConceptSummaryDto> = ConceptSearch.rank(query, findAll())

    /**
     * Full corpus with complete detail (sections, aliases, related ids) in one
     * shot — backs the iOS app's offline-first bundled library and its periodic
     * snapshot sync, so the whole concept library can be pulled in a single
     * request rather than N+1 category + by-id calls.
     */
    fun findAll(): List<ConceptDto> = transaction {
        // Batch-load aliases and related edges once (grouped by concept) rather
        // than issuing a per-concept query in rowToDto. That N+1 was invisible
        // on a zero-latency local DB but became ~1,400 round-trips (=~40s) over
        // a remote managed Postgres; this keeps the whole-corpus fetch to 3 queries.
        val aliasesByConcept: Map<UUID, List<AliasDto>> = Aliases.selectAll()
            .groupBy({ it[Aliases.conceptId] }) {
                AliasDto(id = it[Aliases.id].toString(), text = it[Aliases.aliasText], type = it[Aliases.aliasType])
            }
        val relatedByConcept: Map<UUID, List<String>> = ConceptEdges.selectAll()
            .groupBy({ it[ConceptEdges.fromConceptId] }) { it[ConceptEdges.toConceptId].toString() }

        Concepts.selectAll().map { row ->
            val id = row[Concepts.id]
            ConceptDto(
                id = id.toString(),
                type = ConceptType.valueOf(row[Concepts.type]),
                name = row[Concepts.name],
                shortExplanation = row[Concepts.shortExplanation],
                sections = json.decodeFromString<ConceptSections>(row[Concepts.sectionsJson]),
                tags = json.decodeFromString<List<String>>(row[Concepts.tagsJson]),
                aliases = aliasesByConcept[id] ?: emptyList(),
                relatedConceptIds = relatedByConcept[id] ?: emptyList(),
                pronunciation = row[Concepts.pronunciation],
                assessment = row[Concepts.assessmentJson]?.let { json.decodeFromString<AssessmentScoring>(it) },
                sourceCitation = row[Concepts.sourceCitation]
            )
        }.sortedBy { it.name.lowercase() }
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

    /**
     * Whole-word/phrase keyword matching against the curated corpus (concept
     * names + aliases) — stands in for real NLP/LLM entity extraction
     * (SYSTEM_DESIGN.md "AI/ML pipeline architecture", Roadmap Phase 5, not
     * built yet: no LLM/embeddings integration exists in this codebase).
     * Matches whole terms only (not mid-word substrings), so short aliases
     * like "PE" or "HD" don't fire on unrelated words like "experience" or
     * "shed" — but this is still a blunt keyword match, not comprehension, so
     * false positives/negatives on ambiguous phrasing are expected until a
     * real extraction pipeline replaces this.
     */
    fun findMentions(transcript: String): List<ConceptDto> = transaction {
        findAll().filter { concept ->
            containsWholeTerm(transcript, concept.name) ||
                concept.aliases.any { containsWholeTerm(transcript, it.text) }
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
            pronunciation = row[Concepts.pronunciation],
            assessment = row[Concepts.assessmentJson]?.let { json.decodeFromString<AssessmentScoring>(it) },
            sourceCitation = row[Concepts.sourceCitation]
        )
    }
}

// Negative-lookbehind/lookahead on alphanumeric chars rather than \b: \b
// mishandles terms ending in a symbol (e.g. alias "K+"), since \b only fires
// at a word/non-word transition and both "+" and a following space are
// non-word characters.
private fun containsWholeTerm(text: String, term: String): Boolean {
    val trimmed = term.trim()
    if (trimmed.isEmpty()) return false
    val pattern = Regex("(?i)(?<![A-Za-z0-9])${Regex.escape(trimmed)}(?![A-Za-z0-9])")
    return pattern.containsMatchIn(text)
}

/** Mirrors the type -> primary-detail-field priority in the iOS concept detail page. */
private fun longExplanationFor(type: ConceptType, sections: ConceptSections): String? = when (type) {
    ConceptType.MEDICATION -> sections.nursingImplications ?: sections.sideEffects
    ConceptType.PROCEDURE -> sections.whatToMonitor ?: sections.targetConcern
    ConceptType.CONDITION -> sections.presentation ?: sections.typicalTreatments
    ConceptType.LAB_VALUE -> sections.abnormalMeaning ?: sections.normalRange
    ConceptType.EQUIPMENT -> sections.careConsiderations ?: sections.purpose
    ConceptType.PROTOCOL -> sections.steps ?: sections.triggerCriteria
    ConceptType.ANATOMY -> null
    ConceptType.ASSESSMENT_TOOL -> sections.steps ?: sections.purpose
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

        // Concept identification: keyword/alias matching against the curated
        // corpus — see ConceptRepository.findMentions for why this stands in
        // for real extraction. Persisted as note->concept `mentions` edges
        // (NoteMentions) per REQUIREMENTS.md's knowledge graph model.
        val mentions = ConceptRepository.findMentions(request.transcript)
        mentions.forEach { concept ->
            NoteMentions.insert {
                it[NoteMentions.noteId] = id
                it[NoteMentions.conceptId] = UUID.fromString(concept.id)
                it[NoteMentions.createdAt] = now
            }
        }

        // TODO: transcript cleanup, dedup embedding, RAG-grounded explanation
        // generation, and concept<->concept edge creation still need a real
        // LLM/embeddings integration. See SYSTEM_DESIGN.md "AI/ML pipeline
        // architecture".
        NoteDto(
            id = id.toString(),
            transcript = request.transcript,
            device = request.device,
            phiReviewed = request.phiReviewed,
            createdAt = now.toEpochMilli(),
            mentionedConcepts = mentions.map { concept ->
                MentionedConceptDto(
                    id = concept.id,
                    conceptId = concept.id,
                    conceptName = concept.name,
                    type = concept.type,
                    shortExplanation = concept.shortExplanation,
                    longExplanation = longExplanationFor(concept.type, concept.sections)
                )
            }
        )
    }
}

object ReportRepository {
    fun create(message: String, context: String?): ReportDto = transaction {
        val id = UUID.randomUUID()
        val now = Instant.now()
        Reports.insert {
            it[Reports.id] = id
            it[Reports.message] = message
            it[Reports.context] = context
            it[Reports.createdAt] = now
        }
        ReportDto(id = id.toString(), message = message, createdAt = now.toEpochMilli())
    }
}

