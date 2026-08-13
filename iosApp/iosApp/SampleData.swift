import Foundation

/// Demo seed content for the Chart-lookup tab so the app has something to show
/// on first launch before the user runs a lookup. These are illustrative
/// *sample* entries — unlike the concept corpus (see `ConceptLibrary`, which is
/// real bundled reference data), lookup sessions are inherently user/device-local
/// and start from these examples until replaced by the user's own activity.
///
/// Capture notes intentionally no longer seed samples — that tab starts empty
/// with an empty-state view.
enum SampleData {
    static let lookupSessions: [LookupSession] = [
        LookupSession(
            id: UUID(),
            chiefComplaints: ["CHF exacerbation", "Shortness of breath"],
            medications: [
                MedicationExplanation(id: UUID(), name: "Furosemide", relatedComplaints: ["CHF exacerbation", "Shortness of breath"], shortExplanation: "Helps your body get rid of extra fluid that's making it hard to breathe.", longExplanation: "Loop diuretic — inhibits the Na-K-2Cl cotransporter in the loop of Henle. Watch for hypokalemia, hypotension, and ototoxicity with rapid IV push."),
                MedicationExplanation(id: UUID(), name: "Metoprolol", relatedComplaints: ["CHF exacerbation"], shortExplanation: "Slows and steadies the heartbeat so the heart doesn't have to work as hard.", longExplanation: "Beta-1 selective blocker — reduces heart rate and myocardial oxygen demand."),
                MedicationExplanation(id: UUID(), name: "Lisinopril", relatedComplaints: ["Hypertension", "CHF exacerbation"], shortExplanation: "Relaxes blood vessels to lower blood pressure and take pressure off the heart.", longExplanation: "ACE inhibitor — blocks conversion of angiotensin I to II."),
                MedicationExplanation(id: UUID(), name: "Potassium Chloride", relatedComplaints: ["CHF exacerbation"], shortExplanation: "Furosemide causes the body to lose potassium along with fluid, so this tops it back up to a safe level.", longExplanation: "Electrolyte replacement — must be diluted and infused at a controlled rate.")
            ],
            createdAt: Date().addingTimeInterval(-60 * 10),
            expiresAt: Date().addingTimeInterval(60 * 60 * 24)
        ),
        LookupSession(
            id: UUID(),
            chiefComplaints: ["COPD flare"],
            medications: [
                MedicationExplanation(id: UUID(), name: "Albuterol", relatedComplaints: ["COPD flare"], shortExplanation: "Opens the airways to make breathing easier.", longExplanation: "Short-acting beta-2 agonist bronchodilator."),
                MedicationExplanation(id: UUID(), name: "Prednisone", relatedComplaints: ["COPD flare"], shortExplanation: "Reduces airway inflammation during a flare.", longExplanation: "Systemic corticosteroid."),
                MedicationExplanation(id: UUID(), name: "Ipratropium", relatedComplaints: ["COPD flare"], shortExplanation: "Another airway-opening medication, often paired with albuterol.", longExplanation: "Anticholinergic bronchodilator.")
            ],
            createdAt: Date().addingTimeInterval(-60 * 55),
            expiresAt: Date().addingTimeInterval(60 * 60 * 24)
        ),
        LookupSession(
            id: UUID(),
            chiefComplaints: ["Post-op pain"],
            medications: [
                MedicationExplanation(id: UUID(), name: "Oxycodone", relatedComplaints: ["Post-op pain"], shortExplanation: "Opioid pain reliever for moderate to severe post-surgical pain.", longExplanation: "Monitor respiratory rate and sedation level."),
                MedicationExplanation(id: UUID(), name: "Acetaminophen", relatedComplaints: ["Post-op pain"], shortExplanation: "Non-opioid pain reliever, often used alongside opioids to reduce total opioid dose.", longExplanation: "Monitor total daily dose across all sources.")
            ],
            createdAt: Date().addingTimeInterval(-3600 * 2),
            expiresAt: Date().addingTimeInterval(60 * 60 * 24)
        ),
        LookupSession(
            id: UUID(),
            chiefComplaints: ["Sepsis workup"],
            medications: [
                MedicationExplanation(id: UUID(), name: "Vancomycin", relatedComplaints: ["Sepsis workup"], shortExplanation: "Broad-spectrum antibiotic covering resistant bacteria while cultures are pending.", longExplanation: "Monitor trough levels and renal function."),
                MedicationExplanation(id: UUID(), name: "Piperacillin-tazobactam", relatedComplaints: ["Sepsis workup"], shortExplanation: "Broad-spectrum antibiotic covering a wide range of bacteria.", longExplanation: "Watch for allergic reaction and renal dosing adjustments."),
                MedicationExplanation(id: UUID(), name: "Norepinephrine", relatedComplaints: ["Sepsis workup"], shortExplanation: "Raises blood pressure when fluids alone aren't maintaining perfusion.", longExplanation: "First-line vasopressor in septic shock — requires continuous BP monitoring."),
                MedicationExplanation(id: UUID(), name: "Normal Saline", relatedComplaints: ["Sepsis workup"], shortExplanation: "IV fluid used for aggressive fluid resuscitation.", longExplanation: "Reassess volume status frequently to avoid fluid overload."),
                MedicationExplanation(id: UUID(), name: "Lactate", relatedComplaints: ["Sepsis workup"], shortExplanation: "Blood marker trended to gauge response to resuscitation.", longExplanation: "Trending downward suggests improving tissue perfusion.")
            ],
            createdAt: Date().addingTimeInterval(-3600 * 3),
            expiresAt: Date().addingTimeInterval(60 * 60 * 24)
        )
    ]
}
