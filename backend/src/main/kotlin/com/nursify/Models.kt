package com.nursify

import kotlinx.serialization.Serializable

@Serializable
enum class ConceptType {
    MEDICATION, PROCEDURE, CONDITION, LAB_VALUE, EQUIPMENT, PROTOCOL, ANATOMY, ASSESSMENT_TOOL
}

/**
 * Type-specific concept content. Mirrors the `sections` JSONB column
 * described in SYSTEM_DESIGN.md — stored server-side as serialized JSON in a
 * text column for this first increment (see Tables.kt), with a real jsonb
 * column type as a follow-up once query/index needs justify it.
 */
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

// Structured scoring for ASSESSMENT_TOOL concepts (e.g. GCS, NIHSS) that drives
// the "Score" tab's interactive calculator and the "Learn" tab's component
// table + colour-coded interpretation bands. Optional: tools without a simple
// additive score (CAM-ICU, FAST) leave this null and render Learn-only.
@Serializable
data class AssessmentScoring(
    val components: List<AssessmentComponent>,
    val bands: List<AssessmentBand>,
    val criticalNote: String? = null
)

@Serializable
data class AssessmentComponent(
    val name: String,
    val options: List<AssessmentOption>
)

@Serializable
data class AssessmentOption(
    val label: String,
    val points: Int
)

@Serializable
data class AssessmentBand(
    val min: Int,
    val max: Int,
    val label: String,
    val severity: String // "mild" | "moderate" | "severe"
)

@Serializable
data class AliasDto(
    val id: String,
    val text: String,
    val type: String
)

@Serializable
data class ConceptDto(
    val id: String,
    val type: ConceptType,
    val name: String,
    val shortExplanation: String,
    val sections: ConceptSections,
    val tags: List<String>,
    val aliases: List<AliasDto> = emptyList(),
    val relatedConceptIds: List<String> = emptyList(),
    val pronunciation: String? = null,
    val assessment: AssessmentScoring? = null,
    val sourceCitation: String? = null
)

@Serializable
data class ConceptSummaryDto(
    val id: String,
    val type: ConceptType,
    val name: String,
    val sideEffectsPreview: String? = null
)

@Serializable
data class NoteCreateRequest(
    val transcript: String,
    val device: String = "phone",
    val phiReviewed: Boolean = false
)

@Serializable
data class MentionedConceptDto(
    val id: String,
    val conceptId: String,
    val conceptName: String,
    val type: ConceptType,
    val shortExplanation: String,
    val longExplanation: String? = null
)

@Serializable
data class NoteDto(
    val id: String,
    val transcript: String,
    val device: String,
    val phiReviewed: Boolean,
    // Epoch millis, not Instant.toString() — that emits a variable number of
    // fractional-second digits (0, 3, 6, or 9), which trips up naive iOS
    // Codable date parsing. Epoch millis sidesteps the whole format question.
    val createdAt: Long,
    val mentionedConcepts: List<MentionedConceptDto> = emptyList()
)

@Serializable
data class ChartLookupRequest(
    val chiefComplaints: List<String>,
    val medicationNames: List<String>
)

@Serializable
data class MedicationExplanationDto(
    val name: String,
    val relatedComplaints: List<String>,
    val shortExplanation: String,
    val longExplanation: String? = null,
    val found: Boolean
)

@Serializable
data class ChartLookupResponse(
    val chiefComplaints: List<String>,
    val medications: List<MedicationExplanationDto>
)

@Serializable
data class SuggestionDto(
    val id: String,
    val title: String,
    val reason: String,
    val kind: String
)

@Serializable
data class ReportCreateRequest(
    val message: String,
    val context: String? = null
)

@Serializable
data class ReportDto(
    val id: String,
    val message: String,
    val createdAt: Long // epoch millis — see NoteDto.createdAt comment
)
