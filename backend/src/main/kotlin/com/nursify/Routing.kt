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
            // Full corpus with complete detail — powers the iOS offline-first
            // bundled library and its snapshot sync (one request, no N+1).
            get {
                call.respond(ConceptRepository.findAll())
            }
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
            // See SYSTEM_DESIGN.md "Suggestion engine". The one "core" slot is
            // specialty-aware — see StaticSuggestions.coreFor.
            val specialty = call.request.queryParameters["specialty"]
            call.respond(StaticSuggestions.forSpecialty(specialty))
        }

        post("/chart-lookup") {
            // Stateless by design — nothing here is persisted server-side.
            // The LookupSession this response feeds lives client-local only.
            // See REQUIREMENTS.md "Data retention — shift-scoped, not fully ephemeral".
            val request = call.receive<ChartLookupRequest>()
            val medications = request.medicationNames.map { name ->
                val concept = ConceptRepository.findByNameOrAliasIgnoreCase(name)
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
    private val fixed = listOf(
        SuggestionDto(UUID.randomUUID().toString(), "Beta-blockers (class)", "Last reviewed 9 days ago — spaced review suggests today.", "due"),
        SuggestionDto(UUID.randomUUID().toString(), "Furosemide ↔ fluid balance", "Mentioned 3× in your notes but never explored in depth.", "gap"),
        SuggestionDto(UUID.randomUUID().toString(), "Potassium wasting", "Related to furosemide, which you reviewed yesterday.", "related"),
        SuggestionDto(UUID.randomUUID().toString(), "Furosemide — treats → CHF", "Looked up 6× across different patients this month.", "practice")
    )

    private val defaultCore =
        SuggestionDto(UUID.randomUUID().toString(), "Cardiac rhythm basics", "Foundational for your selected specialty, not yet in your graph.", "core")

    // Keyed on the exact rawValue strings from the iOS `Specialty` enum
    // (iosApp/iosApp/Models.swift) — plain string match, so spelling/spacing/
    // slashes must match verbatim.
    private val coreTitleAndReasonBySpecialty: Map<String, Pair<String, String>> = mapOf(
        "Telemetry" to ("Reading a 6-lead strip" to "Foundational for Telemetry nursing, not yet in your graph."),
        "Med-Surg" to ("Post-op pain management basics" to "Foundational for Med-Surg nursing, not yet in your graph."),
        "Oncology" to ("Neutropenic precautions" to "Foundational for Oncology nursing, not yet in your graph."),
        "ICU / Critical Care" to ("Vasopressor titration basics" to "Foundational for ICU / Critical Care nursing, not yet in your graph."),
        "ER" to ("Triage acuity scoring (ESI)" to "Foundational for ER nursing, not yet in your graph."),
        "L&D / Maternity" to ("Fetal heart rate patterns" to "Foundational for L&D / Maternity nursing, not yet in your graph."),
        "Pediatrics" to ("Weight-based dosing basics" to "Foundational for Pediatrics nursing, not yet in your graph."),
        "NICU" to ("Thermoregulation in neonates" to "Foundational for NICU nursing, not yet in your graph."),
        "Psych / Behavioral Health" to ("De-escalation basics" to "Foundational for Psych / Behavioral Health nursing, not yet in your graph."),
        "OR / Perioperative" to ("Sterile field basics" to "Foundational for OR / Perioperative nursing, not yet in your graph."),
        "PACU" to ("Post-anesthesia airway assessment" to "Foundational for PACU nursing, not yet in your graph."),
        "Renal / Dialysis" to ("Fluid & electrolyte balance in dialysis" to "Foundational for Renal / Dialysis nursing, not yet in your graph."),
        "Rehab" to ("Fall risk assessment basics" to "Foundational for Rehab nursing, not yet in your graph."),
        "Home Health / Hospice" to ("Comfort care medication basics" to "Foundational for Home Health / Hospice nursing, not yet in your graph."),
        "Cardiac Cath Lab" to ("Post-cath sheath care" to "Foundational for Cardiac Cath Lab nursing, not yet in your graph."),
        "Wound Care" to ("Wound staging basics" to "Foundational for Wound Care nursing, not yet in your graph."),
        "Case Management" to ("Discharge planning basics" to "Foundational for Case Management nursing, not yet in your graph."),
        "Float Pool" to ("Core assessment basics across units" to "Foundational for Float Pool nursing, not yet in your graph.")
    )

    private fun coreFor(specialty: String?): SuggestionDto {
        val titleAndReason = specialty?.let { coreTitleAndReasonBySpecialty[it] } ?: return defaultCore
        val (title, reason) = titleAndReason
        return SuggestionDto(UUID.randomUUID().toString(), title, reason, "core")
    }

    fun forSpecialty(specialty: String?): List<SuggestionDto> = fixed + coreFor(specialty)

    // Preserved for any existing callers/tests expecting the old default set.
    val all = fixed + defaultCore
}
