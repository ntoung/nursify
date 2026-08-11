package com.nursify

import io.ktor.http.*
import io.ktor.server.application.*
import io.ktor.server.request.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import java.util.UUID

/**
 * API surface per SYSTEM_DESIGN.md "API surface". No auth yet — matches the
 * still-open "solo personal use vs multi-user" question in REQUIREMENTS.md;
 * every route currently operates over one shared dataset.
 */
fun Application.configureRouting() {
    routing {
        get("/health") {
            call.respondText("ok")
        }

        route("/concepts") {
            get("/search") {
                val q = call.request.queryParameters["q"] ?: ""
                if (q.isBlank()) {
                    call.respond(emptyList<ConceptSummaryDto>())
                    return@get
                }
                call.respond(ConceptRepository.search(q))
            }
            get("/category/{type}") {
                val typeParam = call.parameters["type"] ?: return@get call.respond(HttpStatusCode.BadRequest)
                val type = runCatching { ConceptType.valueOf(typeParam.uppercase()) }.getOrNull()
                    ?: return@get call.respond(HttpStatusCode.BadRequest, "Unknown concept type: $typeParam")
                call.respond(ConceptRepository.byCategory(type))
            }
            get("/{id}") {
                val idParam = call.parameters["id"] ?: return@get call.respond(HttpStatusCode.BadRequest)
                val id = runCatching { UUID.fromString(idParam) }.getOrNull()
                    ?: return@get call.respond(HttpStatusCode.BadRequest, "Invalid id")
                val concept = ConceptRepository.findById(id) ?: return@get call.respond(HttpStatusCode.NotFound)
                call.respond(concept)
            }
        }

        route("/notes") {
            post {
                val request = call.receive<NoteCreateRequest>()
                val note = NoteRepository.create(request)
                call.respond(HttpStatusCode.Created, note)
            }
        }

        route("/search-history") {
            get {
                call.respond(SearchHistoryRepository.all())
            }
            post("/{conceptId}") {
                val idParam = call.parameters["conceptId"] ?: return@post call.respond(HttpStatusCode.BadRequest)
                val id = runCatching { UUID.fromString(idParam) }.getOrNull()
                    ?: return@post call.respond(HttpStatusCode.BadRequest, "Invalid id")
                call.respond(SearchHistoryRepository.record(id))
            }
            delete {
                SearchHistoryRepository.clear()
                call.respond(HttpStatusCode.NoContent)
            }
        }

        get("/suggestions") {
            // Static for now — the real Suggestion Engine (ranking over
            // ReviewSchedule + graph signals) is a follow-up.
            // See SYSTEM_DESIGN.md "Suggestion engine".
            call.respond(StaticSuggestions.all)
        }

        post("/chart-lookup") {
            // Stateless by design — nothing here is persisted server-side.
            // The LookupSession this response feeds lives client-local only.
            // See REQUIREMENTS.md "Data retention — shift-scoped, not fully ephemeral".
            val request = call.receive<ChartLookupRequest>()
            val medications = request.medicationNames.map { name ->
                val concept = ConceptRepository.findByNameIgnoreCase(name)
                if (concept != null) {
                    MedicationExplanationDto(
                        name = concept.name,
                        relatedComplaints = request.chiefComplaints,
                        shortExplanation = concept.shortExplanation,
                        longExplanation = concept.sections.mechanism,
                        found = true
                    )
                } else {
                    MedicationExplanationDto(
                        name = name,
                        relatedComplaints = request.chiefComplaints,
                        shortExplanation = "Explanation not yet available for $name — this concept hasn't been curated yet.",
                        longExplanation = null,
                        found = false
                    )
                }
            }
            call.respond(ChartLookupResponse(chiefComplaints = request.chiefComplaints, medications = medications))
        }
    }
}

object StaticSuggestions {
    val all = listOf(
        SuggestionDto(UUID.randomUUID().toString(), "Beta-blockers (class)", "Last reviewed 9 days ago — spaced review suggests today.", "due"),
        SuggestionDto(UUID.randomUUID().toString(), "Furosemide ↔ fluid balance", "Mentioned 3× in your notes but never explored in depth.", "gap"),
        SuggestionDto(UUID.randomUUID().toString(), "Potassium wasting", "Related to furosemide, which you reviewed yesterday.", "related"),
        SuggestionDto(UUID.randomUUID().toString(), "Furosemide — treats → CHF", "Looked up 6× across different patients this month.", "practice"),
        SuggestionDto(UUID.randomUUID().toString(), "Cardiac rhythm basics", "Foundational for your selected specialty, not yet in your graph.", "core")
    )
}
