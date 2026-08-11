import Foundation

// MARK: - Content taxonomy (see REQUIREMENTS.md "Content taxonomy")

enum ConceptType: String, Codable, CaseIterable, Identifiable {
    case medication = "Medication"
    case procedure = "Procedure"
    case condition = "Condition"
    case labValue = "Lab Value"
    case equipment = "Equipment"
    case protocolOrderSet = "Protocol"
    case anatomy = "Anatomy"

    var id: String { rawValue }
}

enum AliasType: String, Codable {
    case acronym
    case brandName
    case nickname
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
    var relatedConceptIDs: [UUID]
    var sourceCitation: String?
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

struct MedicationExplanation: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var relatedComplaints: [String]
    var shortExplanation: String
    var longExplanation: String?
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
    var conceptID: UUID
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
