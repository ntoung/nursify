import Foundation

/// Stand-in for the backend (Postgres) and on-device store described in
/// SYSTEM_DESIGN.md. Every screen reads from AppState, which seeds itself from
/// this file. Swap for real networking/SQLDelight-equivalent persistence later
/// without touching the views.
enum MockData {
    static let furosemideID = UUID()
    static let metoprololID = UUID()
    static let lisinoprilID = UUID()
    static let potassiumChlorideID = UUID()
    static let chfID = UUID()
    static let loopDiureticsClassID = UUID()
    static let tavrID = UUID()
    static let potassiumLabID = UUID()

    static let concepts: [Concept] = [
        Concept(
            id: furosemideID,
            type: .medication,
            name: "Furosemide",
            shortExplanation: "Helps the body get rid of extra fluid by making the kidneys release more sodium and water — commonly used when fluid buildup makes it hard to breathe or puts strain on the heart.",
            sections: ConceptSections(
                mechanism: "Loop diuretic — inhibits the Na-K-2Cl cotransporter in the loop of Henle. Watch for hypokalemia, hypotension, and ototoxicity with rapid IV push. Monitor renal function, daily weights, and strict I&Os.",
                sideEffects: "Increased urination, dehydration, low potassium (hypokalemia), dizziness or low blood pressure — especially when standing up quickly.",
                adverseEffects: "Hearing changes or ringing in the ears (ototoxicity), particularly with rapid IV push; severe electrolyte imbalance; allergic reaction in patients with sulfa sensitivity.",
                nursingImplications: "Monitor potassium and renal function, watch for orthostatic hypotension, track daily weights and I&Os.",
                commonBrandName: "Lasix. Usually given IV push or PO depending on acuity and how quickly fluid needs to come off."
            ),
            tags: ["Pharmacology", "Loop diuretic", "Telemetry"],
            aliases: [Alias(id: UUID(), text: "Lasix", type: .brandName)],
            relatedConceptIDs: [chfID, loopDiureticsClassID, potassiumLabID],
            sourceCitation: "Source: MedlinePlus, StatPearls — last synced 2 days ago"
        ),
        Concept(
            id: metoprololID,
            type: .medication,
            name: "Metoprolol",
            shortExplanation: "Slows and steadies the heartbeat so the heart doesn't have to work as hard.",
            sections: ConceptSections(
                mechanism: "Beta-1 selective blocker — reduces heart rate and myocardial oxygen demand. Watch for bradycardia and hypotension; hold for HR/BP below parameters.",
                sideEffects: "Fatigue, dizziness, cold extremities, slowed heart rate.",
                adverseEffects: "Symptomatic bradycardia, heart block, bronchospasm in susceptible patients.",
                nursingImplications: "Check apical pulse and blood pressure before administration.",
                commonBrandName: "Lopressor (tartrate) / Toprol-XL (succinate)."
            ),
            tags: ["Pharmacology", "Beta-blocker"],
            aliases: [Alias(id: UUID(), text: "Lopressor", type: .brandName)],
            relatedConceptIDs: [chfID],
            sourceCitation: "Source: MedlinePlus — last synced 2 days ago"
        ),
        Concept(
            id: lisinoprilID,
            type: .medication,
            name: "Lisinopril",
            shortExplanation: "Relaxes blood vessels to lower blood pressure and take pressure off the heart.",
            sections: ConceptSections(
                mechanism: "ACE inhibitor — blocks conversion of angiotensin I to II, reducing vasoconstriction and aldosterone release.",
                sideEffects: "Dry cough, dizziness, elevated potassium.",
                adverseEffects: "Angioedema (rare but serious), hyperkalemia, acute kidney injury in volume-depleted patients.",
                nursingImplications: "Monitor blood pressure and potassium; watch for signs of angioedema (lip/tongue swelling).",
                commonBrandName: "Zestril / Prinivil."
            ),
            tags: ["Pharmacology", "ACE inhibitor"],
            aliases: [Alias(id: UUID(), text: "Zestril", type: .brandName)],
            relatedConceptIDs: [chfID],
            sourceCitation: "Source: MedlinePlus — last synced 2 days ago"
        ),
        Concept(
            id: potassiumChlorideID,
            type: .medication,
            name: "Potassium Chloride",
            shortExplanation: "Furosemide causes the body to lose potassium along with fluid, so this tops it back up to a safe level.",
            sections: ConceptSections(
                mechanism: "Electrolyte replacement. IV formulations must always be diluted and infused at a controlled rate — never given IV push.",
                sideEffects: "GI upset (oral form), infusion site discomfort (IV form).",
                adverseEffects: "Cardiac arrhythmia if infused too quickly or given undiluted IV; hyperkalemia if over-repleted.",
                nursingImplications: "Verify potassium level and renal function before administering; use an infusion pump for IV doses.",
                commonBrandName: "K-Dur, Klor-Con (oral forms)."
            ),
            tags: ["Pharmacology", "Electrolyte replacement"],
            aliases: [],
            relatedConceptIDs: [furosemideID, potassiumLabID],
            sourceCitation: "Source: MedlinePlus — last synced 2 days ago"
        ),
        Concept(
            id: chfID,
            type: .condition,
            name: "CHF Exacerbation",
            shortExplanation: "Acute worsening of heart failure symptoms, often from fluid overload, causing shortness of breath and reduced ability to pump blood effectively.",
            sections: ConceptSections(
                presentation: "Dyspnea, orthopnea, crackles on lung auscultation, jugular venous distension, peripheral edema, rapid weight gain.",
                typicalTreatments: "Loop diuretics (furosemide), beta-blockers, ACE inhibitors/ARBs, fluid and sodium restriction.",
                riskFactors: "Prior heart failure, uncontrolled hypertension, medication/dietary non-adherence, arrhythmia, ischemia."
            ),
            tags: ["Cardiology", "Telemetry"],
            aliases: [
                Alias(id: UUID(), text: "CHF", type: .acronym),
                Alias(id: UUID(), text: "Acute decompensated heart failure", type: .nickname)
            ],
            relatedConceptIDs: [furosemideID, metoprololID, lisinoprilID],
            sourceCitation: "Source: MedlinePlus, StatPearls"
        ),
        Concept(
            id: loopDiureticsClassID,
            type: .medication,
            name: "Loop Diuretics (class)",
            shortExplanation: "The drug class furosemide belongs to — more potent than thiazide diuretics.",
            sections: ConceptSections(
                mechanism: "Act on the thick ascending limb of the loop of Henle rather than the distal tubule, producing a stronger diuretic effect — preferred when rapid, aggressive fluid removal is needed, as in an acute CHF exacerbation.",
                sideEffects: "Electrolyte depletion (potassium, magnesium, sodium), dehydration.",
                adverseEffects: "Ototoxicity with rapid IV administration, especially at high doses."
            ),
            tags: ["Pharmacology"],
            aliases: [],
            relatedConceptIDs: [furosemideID],
            sourceCitation: "Source: StatPearls"
        ),
        Concept(
            id: tavrID,
            type: .procedure,
            name: "TAVR",
            shortExplanation: "A minimally invasive procedure that replaces a narrowed aortic valve without open-heart surgery, using a catheter threaded through a blood vessel.",
            sections: ConceptSections(
                targetConcern: "Severe aortic stenosis in patients who are poor candidates for open surgical valve replacement.",
                whatToMonitor: "Access site (usually femoral) for bleeding/hematoma, rhythm changes (risk of new conduction block/need for pacemaker), blood pressure, signs of stroke.",
                medicationsUsed: ["Anticoagulation", "Sedation reversal agents"]
            ),
            tags: ["Cardiology", "Cardiac Cath Lab"],
            aliases: [
                Alias(id: UUID(), text: "TAVR", type: .acronym),
                Alias(id: UUID(), text: "Transcatheter Aortic Valve Replacement", type: .nickname)
            ],
            relatedConceptIDs: [],
            sourceCitation: "Source: StatPearls"
        ),
        Concept(
            id: potassiumLabID,
            type: .labValue,
            name: "Potassium",
            shortExplanation: "An electrolyte critical for heart and muscle function — closely monitored in patients on diuretics.",
            sections: ConceptSections(
                normalRange: "3.5–5.0 mEq/L",
                abnormalMeaning: "Low (hypokalemia): muscle weakness, arrhythmia risk — common with loop diuretics. High (hyperkalemia): cardiac arrhythmia risk — common with ACE inhibitors/renal impairment."
            ),
            tags: ["Lab values", "Telemetry"],
            aliases: [Alias(id: UUID(), text: "K+", type: .acronym)],
            relatedConceptIDs: [furosemideID, potassiumChlorideID],
            sourceCitation: "Source: MedlinePlus"
        )
    ]

    static let notes: [Note] = [
        Note(
            id: UUID(),
            transcript: "\"Pt on furosemide 40mg IV BID for CHF exacerbation — need to review why loop over thiazide here\"",
            device: .phone,
            phiFlagged: false,
            createdAt: Date().addingTimeInterval(-3600 * 2),
            mentionedConcepts: [
                MentionedConcept(id: UUID(), conceptID: furosemideID, conceptName: "Furosemide", type: .medication, shortExplanation: "Loop diuretic that helps reduce fluid overload.", longExplanation: nil),
                MentionedConcept(id: UUID(), conceptID: chfID, conceptName: "CHF Exacerbation", type: .condition, shortExplanation: "Acute worsening of heart failure symptoms, often from fluid overload.", longExplanation: nil),
                MentionedConcept(id: UUID(), conceptID: loopDiureticsClassID, conceptName: "Loop Diuretics (class)", type: .medication, shortExplanation: "The drug class furosemide belongs to — more potent than thiazide diuretics.", longExplanation: "Loop diuretics act on the thick ascending limb of the loop of Henle rather than the distal tubule, producing a stronger diuretic effect — preferred when rapid, aggressive fluid removal is needed, as in an acute CHF exacerbation.")
            ]
        ),
        Note(
            id: UUID(),
            transcript: "Typed: telemetry strips — reviewing 2nd degree AV block type I vs II",
            device: .phone,
            phiFlagged: false,
            createdAt: Date().addingTimeInterval(-3600 * 3),
            mentionedConcepts: []
        ),
        Note(
            id: UUID(),
            transcript: "\"New admit report-off — going to look into metoprolol vs carvedilol dosing differences later\"",
            device: .phone,
            phiFlagged: false,
            createdAt: Date().addingTimeInterval(-3600 * 26),
            mentionedConcepts: [
                MentionedConcept(id: UUID(), conceptID: metoprololID, conceptName: "Metoprolol", type: .medication, shortExplanation: "Slows and steadies the heartbeat so the heart doesn't have to work as hard.", longExplanation: nil)
            ]
        ),
        Note(
            id: UUID(),
            transcript: "Typed: preceptor mentioned daily weights + strict I&Os for CHF patients",
            device: .phone,
            phiFlagged: false,
            createdAt: Date().addingTimeInterval(-3600 * 30),
            mentionedConcepts: []
        )
    ]

    static let suggestions: [Suggestion] = [
        Suggestion(id: UUID(), title: "Beta-blockers (class)", reason: "Last reviewed 9 days ago — spaced review suggests today.", kind: .due),
        Suggestion(id: UUID(), title: "Furosemide ↔ fluid balance", reason: "Mentioned 3× in your notes but never explored in depth.", kind: .gap),
        Suggestion(id: UUID(), title: "Potassium wasting", reason: "Related to furosemide, which you reviewed yesterday.", kind: .related),
        Suggestion(id: UUID(), title: "Furosemide — treats → CHF", reason: "Looked up 6× across different patients this month.", kind: .practice),
        Suggestion(id: UUID(), title: "Cardiac rhythm basics", reason: "Foundational for your selected specialty, not yet in your graph.", kind: .core),
        Suggestion(id: UUID(), title: "12-lead EKG interpretation", reason: "Foundational for Telemetry, not yet in your graph.", kind: .core)
    ]

    static let searchHistory: [SearchHistoryEntry] = [
        SearchHistoryEntry(id: UUID(), conceptID: furosemideID, conceptName: "Furosemide", type: .medication, viewedAt: Date().addingTimeInterval(-3600 * 2)),
        SearchHistoryEntry(id: UUID(), conceptID: tavrID, conceptName: "TAVR", type: .procedure, viewedAt: Date().addingTimeInterval(-3600 * 22)),
        SearchHistoryEntry(id: UUID(), conceptID: chfID, conceptName: "CHF Exacerbation", type: .condition, viewedAt: Date().addingTimeInterval(-3600 * 23)),
        SearchHistoryEntry(id: UUID(), conceptID: potassiumLabID, conceptName: "Potassium", type: .labValue, viewedAt: Date().addingTimeInterval(-3600 * 48))
    ]

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
