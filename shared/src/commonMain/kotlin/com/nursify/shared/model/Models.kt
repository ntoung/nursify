package com.nursify.shared.model

import kotlinx.serialization.Serializable

/**
 * Canonical data model shared across clients. This is the source of truth
 * going forward for the shape already hand-duplicated in
 * iosApp/iosApp/Models.swift and backend/.../Models.kt — wiring the iOS app
 * to actually consume this module (as a compiled framework) instead of its
 * own Swift structs is a follow-up that needs Xcode/macOS. See shared/README.md.
 */

@Serializable
enum class ConceptType {
    MEDICATION, PROCEDURE, CONDITION, LAB_VALUE, EQUIPMENT, PROTOCOL, ANATOMY
}

@Serializable
data class ConceptSections(
    val mechanism: String? = null,
    val sideEffects: String? = null,
    val adverseEffects: String? = null,
    val nursingImplications: String? = null,
    val commonBrandName: String? = null,
    val targetConcern: String? = null,
    val whatToMonitor: String? = null,
    val medicationsUsed: List<String>? = null,
    val presentation: String? = null,
    val typicalTreatments: String? = null,
    val riskFactors: String? = null,
    val normalRange: String? = null,
    val abnormalMeaning: String? = null,
    val purpose: String? = null,
    val careConsiderations: String? = null,
    val triggerCriteria: String? = null,
    val steps: String? = null
)

@Serializable
data class Alias(
    val id: String,
    val text: String,
    val type: String
)

@Serializable
data class Concept(
    val id: String,
    val type: ConceptType,
    val name: String,
    val shortExplanation: String,
    val sections: ConceptSections,
    val tags: List<String> = emptyList(),
    val aliases: List<Alias> = emptyList(),
    val relatedConceptIds: List<String> = emptyList(),
    val sourceCitation: String? = null
)

@Serializable
data class ConceptSummary(
    val id: String,
    val type: ConceptType,
    val name: String,
    val sideEffectsPreview: String? = null
)

@Serializable
data class MedicationExplanation(
    val name: String,
    val relatedComplaints: List<String>,
    val shortExplanation: String,
    val longExplanation: String? = null,
    val found: Boolean = true
)

@Serializable
data class ChartLookupRequest(
    val chiefComplaints: List<String>,
    val medicationNames: List<String>
)

@Serializable
data class ChartLookupResponse(
    val chiefComplaints: List<String>,
    val medications: List<MedicationExplanation>
)

@Serializable
data class NoteCreateRequest(
    val transcript: String,
    val device: String = "phone",
    val phiReviewed: Boolean = false
)

@Serializable
data class NoteDto(
    val id: String,
    val transcript: String,
    val device: String,
    val phiReviewed: Boolean,
    val createdAt: String
)

@Serializable
data class Suggestion(
    val id: String,
    val title: String,
    val reason: String,
    val kind: String
)

@Serializable
data class SearchHistoryEntry(
    val id: String,
    val conceptId: String,
    val conceptName: String,
    val type: ConceptType,
    val viewedAt: String
)

enum class Specialty(val label: String) {
    TELEMETRY("Telemetry"),
    MED_SURG("Med-Surg"),
    ONCOLOGY("Oncology"),
    ICU_CRITICAL_CARE("ICU / Critical Care"),
    ER("ER"),
    LABOR_AND_DELIVERY("L&D / Maternity"),
    PEDIATRICS("Pediatrics"),
    NICU("NICU"),
    PSYCH("Psych / Behavioral Health"),
    OR_PERIOPERATIVE("OR / Perioperative"),
    PACU("PACU"),
    RENAL_DIALYSIS("Renal / Dialysis"),
    REHAB("Rehab"),
    HOME_HEALTH_HOSPICE("Home Health / Hospice"),
    CARDIAC_CATH_LAB("Cardiac Cath Lab"),
    WOUND_CARE("Wound Care"),
    CASE_MANAGEMENT("Case Management"),
    FLOAT_POOL("Float Pool")
}

enum class ExperienceLevel(val label: String) {
    NEW_GRAD("New grad (<1 yr)"),
    ONE_TO_THREE("1–3 years"),
    FOUR_TO_SEVEN("4–7 years"),
    EIGHT_TO_FIFTEEN("8–15 years"),
    FIFTEEN_PLUS("15+ years")
}

@Serializable
data class UserProfile(
    val specialties: Set<String> = emptySet(),
    val experienceLevel: String? = null
)
