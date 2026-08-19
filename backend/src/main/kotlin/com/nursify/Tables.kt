package com.nursify

import org.jetbrains.exposed.sql.Table
import org.jetbrains.exposed.sql.javatime.timestamp

/**
 * Data model per SYSTEM_DESIGN.md. Two deliberate simplifications for this
 * first buildable increment, both called out there as follow-ups:
 *  - `Concepts.sectionsJson` / `tagsJson` are plain text columns holding
 *    serialized JSON rather than a true `jsonb` column type.
 *  - No `CorpusChunk` / pgvector embedding columns yet — those need a real
 *    embeddings integration (RAG is roadmap Phase 6, later than this).
 *
 * `LookupSession` (Feature B) intentionally has no table here at all — it's
 * client-local only per REQUIREMENTS.md, never persisted server-side.
 */

object Concepts : Table("concepts") {
    val id = uuid("id")
    val type = varchar("type", 32)
    val name = varchar("name", 255)
    val shortExplanation = text("short_explanation")
    val sectionsJson = text("sections_json")
    val tagsJson = text("tags_json")
    val pronunciation = text("pronunciation").nullable()
    val assessmentJson = text("assessment_json").nullable()
    val sourceCitation = text("source_citation").nullable()
    val createdAt = timestamp("created_at")

    override val primaryKey = PrimaryKey(id)
}

object Aliases : Table("aliases") {
    val id = uuid("id")
    val conceptId = uuid("concept_id").references(Concepts.id)
    val aliasText = varchar("alias_text", 255)
    val aliasType = varchar("alias_type", 32)

    override val primaryKey = PrimaryKey(id)
}

object ConceptEdges : Table("concept_edges") {
    val id = uuid("id")
    val fromConceptId = uuid("from_concept_id").references(Concepts.id)
    val toConceptId = uuid("to_concept_id").references(Concepts.id)
    val edgeType = varchar("edge_type", 32)
    val weight = integer("weight").default(1)
    val createdAt = timestamp("created_at")
    val lastReinforcedAt = timestamp("last_reinforced_at")

    override val primaryKey = PrimaryKey(id)
}

object Notes : Table("notes") {
    val id = uuid("id")
    val transcript = text("transcript")
    val device = varchar("device", 16)
    val phiReviewed = bool("phi_reviewed").default(false)
    val createdAt = timestamp("created_at")

    override val primaryKey = PrimaryKey(id)
}

object NoteMentions : Table("note_mentions") {
    val noteId = uuid("note_id").references(Notes.id)
    val conceptId = uuid("concept_id").references(Concepts.id)
    val createdAt = timestamp("created_at")

    override val primaryKey = PrimaryKey(noteId, conceptId)
}

object ReviewSchedules : Table("review_schedules") {
    val id = uuid("id")
    val conceptId = uuid("concept_id").references(Concepts.id)
    val dueAt = timestamp("due_at")
    val intervalDays = integer("interval_days").default(1)
    val easeFactor = double("ease_factor").default(2.5)
    val lastReviewedAt = timestamp("last_reviewed_at").nullable()

    override val primaryKey = PrimaryKey(id)
}

// User-submitted "Report a problem" feedback (shake-to-report). `context` holds
// optional app/device info; no PHI is expected here.
object Reports : Table("reports") {
    val id = uuid("id")
    val message = text("message")
    val context = text("context").nullable()
    val createdAt = timestamp("created_at")

    override val primaryKey = PrimaryKey(id)
}
