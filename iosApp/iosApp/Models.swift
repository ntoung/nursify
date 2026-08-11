import Foundation

// MARK: - Content taxonomy (see REQUIREMENTS.md "Content taxonomy")

// Raw values match the backend's wire format exactly (kotlinx.serialization's
// default enum encoding is the constant name) so Codable can decode them
// with no custom logic. `displayName` is the UI-friendly label — the two
// used to be the same string, which broke once the app started decoding
// real network responses instead of only ever constructing these locally.
enum ConceptType: String, Codable, CaseIterable, Identifiable {
    case medication = "MEDICATION"
    case procedure = "PROCEDURE"
    case condition = "CONDITION"
    case labValue = "LAB_VALUE"
    case equipment = "EQUIPMENT"
    case protocolOrderSet = "PROTOCOL"
    case anatomy = "ANATOMY"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .medication: return "Medication"
        case .procedure: return "Procedure"
        case .condition: return "Condition"
        case .labValue: return "Lab Value"
        case .equipment: return "Equipment"
        case .protocolOrderSet: return "Protocol"
        case .anatomy: return "Anatomy"
        }
    }
}

enum AliasType: String, Codable {
    case acronym = "ACRONYM"
    case brandName = "BRAND_NAME"
    case nickname = "NICKNAME"
}

struct Alias: Identifiable, Codable, Hashable {
    let id: UUID
    var text: String
    var type: AliasType
}

/// Type-specific concept content. Mirrors the `sections` JSONB column described
/// in SYSTEM_DESIGN.md — modeled client-side as optional fields rather than a
/// dictionary for simplicity; only the fields relevant to a concept's `type`
/// are ever populated.
struct ConceptSections: Codable, Hashable {
    var mechanism: String?
    var sideEffects: String?
    var adverseEffects: String?
    var nursingImplications: String?
    var commonBrandName: String?
    var targetConcern: String?
    var whatToMonitor: String?
    var medicationsUsed: [String]?
    var presentation: String?
    var typicalTreatments: String?
    var riskFactors: String?
    var normalRange: String?
    var abnormalMeaning: String?
    var purpose: String?
    var careConsiderations: String?
    var triggerCriteria: String?
    var steps: String?

    init(
        mechanism: String? = nil,
        sideEffects: String? = nil,
        adverseEffects: String? = nil,
        nursingImplications: String? = nil,
        commonBrandName: String? = nil,
        targetConcern: String? = nil,
        whatToMonitor: String? = nil,
        medicationsUsed: [String]? = nil,
        presentation: String? = nil,
        typicalTreatments: String? = nil,
        riskFactors: String? = nil,
        normalRange: String? = nil,
        abnormalMeaning: String? = nil,
        purpose: String? = nil,
        careConsiderations: String? = nil,
        triggerCriteria: String? = nil,
        steps: String? = nil
    ) {
        self.mechanism = mechanism
        self.sideEffects = sideEffects
        self.adverseEffects = adverseEffects
        self.nursingImplications = nursingImplications
        self.commonBrandName = commonBrandName
        self.targetConcern = targetConcern
        self.whatToMonitor = whatToMonitor
        self.medicationsUsed = medicationsUsed
        self.presentation = presentation
        self.typicalTreatments = typicalTreatments
        self.riskFactors = riskFactors
        self.normalRange = normalRange
        self.abnormalMeaning = abnormalMeaning
        self.purpose = purpose
        self.careConsiderations = careConsiderations
        self.triggerCriteria = triggerCriteria
        self.steps = steps
    }
}

struct Concept: Identifiable, Codable, Hashable {
    let id: UUID
    var type: ConceptType
    var name: String
    var shortExplanation: String
    var sections: ConceptSections
    var tags: [String]
    var aliases: [Alias]
    var relatedConceptIds: [UUID]
    var sourceCitation: String?
}

/// Lightweight result shape for search/category-browse — matches the
/// backend's ConceptSummaryDto. Full detail (sections, related concepts,
/// citation) is fetched separately by id once a concept is actually opened.
struct ConceptSummary: Identifiable, Codable, Hashable {
    let id: UUID
    var type: ConceptType
    var name: String
    var sideEffectsPreview: String?
}

// MARK: - Capture (Feature A)

enum CaptureDevice: String, Codable {
    case phone
    case watch
}

struct MentionedConcept: Identifiable, Codable, Hashable {
    let id: UUID
    var conceptID: UUID
    var conceptName: String
    var type: ConceptType
    var shortExplanation: String
    var longExplanation: String?
}

struct Note: Identifiable, Codable, Hashable {
    let id: UUID
    var transcript: String
    var device: CaptureDevice
    var phiFlagged: Bool
    var createdAt: Date
    var mentionedConcepts: [MentionedConcept]
}

// MARK: - Chart lookup (Feature B) — LookupSession is client-local only,
// never persisted to the backend. See SYSTEM_DESIGN.md "Chart lookup (Feature B)".

// Custom Codable: the backend's MedicationExplanationDto has no "id" field
// (it's not a persisted entity server-side) and does have "found", which
// the naive synthesized version of this struct was missing entirely —
// decoding a real chart-lookup response would have thrown keyNotFound("id").
struct MedicationExplanation: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var relatedComplaints: [String]
    var shortExplanation: String
    var longExplanation: String?
    var found: Bool

    init(
        id: UUID = UUID(),
        name: String,
        relatedComplaints: [String],
        shortExplanation: String,
        longExplanation: String? = nil,
        found: Bool = true
    ) {
        self.id = id
        self.name = name
        self.relatedComplaints = relatedComplaints
        self.shortExplanation = shortExplanation
        self.longExplanation = longExplanation
        self.found = found
    }

    private enum CodingKeys: String, CodingKey {
        case name, relatedComplaints, shortExplanation, longExplanation, found
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = UUID()
        name = try container.decode(String.self, forKey: .name)
        relatedComplaints = try container.decode([String].self, forKey: .relatedComplaints)
        shortExplanation = try container.decode(String.self, forKey: .shortExplanation)
        longExplanation = try container.decodeIfPresent(String.self, forKey: .longExplanation)
        found = try container.decodeIfPresent(Bool.self, forKey: .found) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(relatedComplaints, forKey: .relatedComplaints)
        try container.encode(shortExplanation, forKey: .shortExplanation)
        try container.encodeIfPresent(longExplanation, forKey: .longExplanation)
        try container.encode(found, forKey: .found)
    }
}

struct LookupSession: Identifiable, Codable, Hashable {
    let id: UUID
    var chiefComplaints: [String]
    var medications: [MedicationExplanation]
    var createdAt: Date
    var expiresAt: Date
}

// MARK: - Onboarding / user profile

enum Specialty: String, Codable, CaseIterable, Identifiable {
    case telemetry = "Telemetry"
    case medSurg = "Med-Surg"
    case oncology = "Oncology"
    case icuCriticalCare = "ICU / Critical Care"
    case er = "ER"
    case laborAndDelivery = "L&D / Maternity"
    case pediatrics = "Pediatrics"
    case nicu = "NICU"
    case psych = "Psych / Behavioral Health"
    case orPerioperative = "OR / Perioperative"
    case pacu = "PACU"
    case renalDialysis = "Renal / Dialysis"
    case rehab = "Rehab"
    case homeHealthHospice = "Home Health / Hospice"
    case cardiacCathLab = "Cardiac Cath Lab"
    case woundCare = "Wound Care"
    case caseManagement = "Case Management"
    case floatPool = "Float Pool"

    var id: String { rawValue }
}

enum ExperienceLevel: String, Codable, CaseIterable, Identifiable {
    case newGrad = "New grad (<1 yr)"
    case oneToThree = "1–3 years"
    case fourToSeven = "4–7 years"
    case eightToFifteen = "8–15 years"
    case fifteenPlus = "15+ years"

    var id: String { rawValue }
}

struct UserProfile: Codable {
    var specialties: Set<Specialty>
    var experienceLevel: ExperienceLevel?
}

// MARK: - Suggestion engine

enum SuggestionKind: String, Codable {
    case due
    case gap
    case related
    case practice
    case core
}

struct Suggestion: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var reason: String
    var kind: SuggestionKind
}

// MARK: - Search history (Learn page)

struct SearchHistoryEntry: Identifiable, Codable, Hashable {
    let id: UUID
    var conceptId: UUID
    var conceptName: String
    var type: ConceptType
    var viewedAt: Date
}

extension Date {
    var relativeDescription: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
