package com.nursify

import org.jetbrains.exposed.sql.selectAll
import org.jetbrains.exposed.sql.transactions.transaction
import java.util.UUID

/**
 * Seeds the same concepts as iosApp/iosApp/MockData.swift so client and
 * backend agree on demo content while there's no real AI-augmentation
 * pipeline populating the graph yet.
 */
object SeedData {
    fun seedIfEmpty() {
        val alreadySeeded = transaction { Concepts.selectAll().limit(1).any() }
        if (alreadySeeded) return

        val furosemideId = UUID.randomUUID()
        val metoprololId = UUID.randomUUID()
        val lisinoprilId = UUID.randomUUID()
        val potassiumChlorideId = UUID.randomUUID()
        val chfId = UUID.randomUUID()
        val loopDiureticsClassId = UUID.randomUUID()
        val tavrId = UUID.randomUUID()
        val potassiumLabId = UUID.randomUUID()

        ConceptRepository.insert(
            id = furosemideId,
            type = ConceptType.MEDICATION,
            name = "Furosemide",
            shortExplanation = "Helps the body get rid of extra fluid by making the kidneys release more sodium and water — commonly used when fluid buildup makes it hard to breathe or puts strain on the heart.",
            sections = ConceptSections(
                mechanism = "Loop diuretic — inhibits the Na-K-2Cl cotransporter in the loop of Henle. Watch for hypokalemia, hypotension, and ototoxicity with rapid IV push.",
                sideEffects = "Increased urination, dehydration, low potassium (hypokalemia), dizziness or low blood pressure.",
                adverseEffects = "Hearing changes or ringing in the ears (ototoxicity) with rapid IV push; severe electrolyte imbalance; allergic reaction in patients with sulfa sensitivity.",
                nursingImplications = "Monitor potassium and renal function, watch for orthostatic hypotension, track daily weights and I&Os.",
                commonBrandName = "Lasix. Usually given IV push or PO depending on acuity."
            ),
            tags = listOf("Pharmacology", "Loop diuretic", "Telemetry"),
            sourceCitation = "Source: MedlinePlus, StatPearls"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), furosemideId, "Lasix", "BRAND_NAME")

        ConceptRepository.insert(
            id = metoprololId,
            type = ConceptType.MEDICATION,
            name = "Metoprolol",
            shortExplanation = "Slows and steadies the heartbeat so the heart doesn't have to work as hard.",
            sections = ConceptSections(
                mechanism = "Beta-1 selective blocker — reduces heart rate and myocardial oxygen demand.",
                sideEffects = "Fatigue, dizziness, cold extremities, slowed heart rate.",
                adverseEffects = "Symptomatic bradycardia, heart block, bronchospasm in susceptible patients.",
                nursingImplications = "Check apical pulse and blood pressure before administration.",
                commonBrandName = "Lopressor (tartrate) / Toprol-XL (succinate)."
            ),
            tags = listOf("Pharmacology", "Beta-blocker"),
            sourceCitation = "Source: MedlinePlus"
        )

        ConceptRepository.insert(
            id = lisinoprilId,
            type = ConceptType.MEDICATION,
            name = "Lisinopril",
            shortExplanation = "Relaxes blood vessels to lower blood pressure and take pressure off the heart.",
            sections = ConceptSections(
                mechanism = "ACE inhibitor — blocks conversion of angiotensin I to II.",
                sideEffects = "Dry cough, dizziness, elevated potassium.",
                adverseEffects = "Angioedema (rare but serious), hyperkalemia, acute kidney injury in volume-depleted patients.",
                nursingImplications = "Monitor blood pressure and potassium; watch for signs of angioedema.",
                commonBrandName = "Zestril / Prinivil."
            ),
            tags = listOf("Pharmacology", "ACE inhibitor"),
            sourceCitation = "Source: MedlinePlus"
        )

        ConceptRepository.insert(
            id = potassiumChlorideId,
            type = ConceptType.MEDICATION,
            name = "Potassium Chloride",
            shortExplanation = "Furosemide causes the body to lose potassium along with fluid, so this tops it back up to a safe level.",
            sections = ConceptSections(
                mechanism = "Electrolyte replacement. IV formulations must always be diluted and infused at a controlled rate.",
                sideEffects = "GI upset (oral form), infusion site discomfort (IV form).",
                adverseEffects = "Cardiac arrhythmia if infused too quickly or given undiluted IV.",
                nursingImplications = "Verify potassium level and renal function before administering.",
                commonBrandName = "K-Dur, Klor-Con (oral forms)."
            ),
            tags = listOf("Pharmacology", "Electrolyte replacement"),
            sourceCitation = "Source: MedlinePlus"
        )

        ConceptRepository.insert(
            id = chfId,
            type = ConceptType.CONDITION,
            name = "CHF Exacerbation",
            shortExplanation = "Acute worsening of heart failure symptoms, often from fluid overload.",
            sections = ConceptSections(
                presentation = "Dyspnea, orthopnea, crackles on lung auscultation, jugular venous distension, peripheral edema.",
                typicalTreatments = "Loop diuretics (furosemide), beta-blockers, ACE inhibitors/ARBs, fluid and sodium restriction.",
                riskFactors = "Prior heart failure, uncontrolled hypertension, medication/dietary non-adherence."
            ),
            tags = listOf("Cardiology", "Telemetry"),
            sourceCitation = "Source: MedlinePlus, StatPearls"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), chfId, "CHF", "ACRONYM")

        ConceptRepository.insert(
            id = loopDiureticsClassId,
            type = ConceptType.MEDICATION,
            name = "Loop Diuretics (class)",
            shortExplanation = "The drug class furosemide belongs to — more potent than thiazide diuretics.",
            sections = ConceptSections(
                mechanism = "Act on the thick ascending limb of the loop of Henle rather than the distal tubule, producing a stronger diuretic effect.",
                sideEffects = "Electrolyte depletion (potassium, magnesium, sodium), dehydration.",
                adverseEffects = "Ototoxicity with rapid IV administration, especially at high doses."
            ),
            tags = listOf("Pharmacology"),
            sourceCitation = "Source: StatPearls"
        )

        ConceptRepository.insert(
            id = tavrId,
            type = ConceptType.PROCEDURE,
            name = "TAVR",
            shortExplanation = "A minimally invasive procedure that replaces a narrowed aortic valve without open-heart surgery.",
            sections = ConceptSections(
                targetConcern = "Severe aortic stenosis in patients who are poor candidates for open surgical valve replacement.",
                whatToMonitor = "Access site for bleeding/hematoma, rhythm changes, blood pressure, signs of stroke.",
                medicationsUsed = listOf("Anticoagulation", "Sedation reversal agents")
            ),
            tags = listOf("Cardiology", "Cardiac Cath Lab"),
            sourceCitation = "Source: StatPearls"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), tavrId, "Transcatheter Aortic Valve Replacement", "NICKNAME")

        ConceptRepository.insert(
            id = potassiumLabId,
            type = ConceptType.LAB_VALUE,
            name = "Potassium",
            shortExplanation = "An electrolyte critical for heart and muscle function — closely monitored in patients on diuretics.",
            sections = ConceptSections(
                normalRange = "3.5–5.0 mEq/L",
                abnormalMeaning = "Low: muscle weakness, arrhythmia risk — common with loop diuretics. High: cardiac arrhythmia risk."
            ),
            tags = listOf("Lab values", "Telemetry"),
            sourceCitation = "Source: MedlinePlus"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), potassiumLabId, "K+", "ACRONYM")

        ConceptRepository.insertEdge(UUID.randomUUID(), furosemideId, chfId, "TREATS")
        ConceptRepository.insertEdge(UUID.randomUUID(), furosemideId, loopDiureticsClassId, "IS_A")
        ConceptRepository.insertEdge(UUID.randomUUID(), furosemideId, potassiumLabId, "RELATED_TO")
        ConceptRepository.insertEdge(UUID.randomUUID(), metoprololId, chfId, "TREATS")
        ConceptRepository.insertEdge(UUID.randomUUID(), lisinoprilId, chfId, "TREATS")
        ConceptRepository.insertEdge(UUID.randomUUID(), potassiumChlorideId, furosemideId, "RELATED_TO")
        ConceptRepository.insertEdge(UUID.randomUUID(), potassiumChlorideId, potassiumLabId, "RELATED_TO")
    }
}
