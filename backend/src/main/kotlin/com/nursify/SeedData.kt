package com.nursify

import org.jetbrains.exposed.sql.selectAll
import org.jetbrains.exposed.sql.transactions.transaction
import java.util.UUID

/**
 * Hand-curated seed content — stands in for the real AI-augmentation +
 * corpus-ingestion pipelines (SYSTEM_DESIGN.md roadmap Phases 5-6), neither
 * of which exist yet. The first 8 concepts also exist as static mock data in
 * iosApp/iosApp/MockData.swift; everything added after that is backend-only
 * now that iOS fetches live content over the network instead.
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

        val heparinId = UUID.randomUUID()
        val warfarinId = UUID.randomUUID()
        val insulinId = UUID.randomUUID()
        val vancomycinId = UUID.randomUUID()
        val albuterolId = UUID.randomUUID()
        val norepinephrineId = UUID.randomUUID()
        val amiodaroneId = UUID.randomUUID()

        val centralLineId = UUID.randomUUID()
        val intubationId = UUID.randomUUID()
        val chestTubeId = UUID.randomUUID()

        val copdExacerbationId = UUID.randomUUID()
        val sepsisId = UUID.randomUUID()
        val dkaId = UUID.randomUUID()
        val atrialFibrillationId = UUID.randomUUID()
        val pulmonaryEmbolismId = UUID.randomUUID()

        val troponinId = UUID.randomUUID()
        val inrId = UUID.randomUUID()
        val lactateId = UUID.randomUUID()
        val glucoseId = UUID.randomUUID()

        val sepsisBundleId = UUID.randomUUID()

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

        // --- Medications ---

        ConceptRepository.insert(
            id = heparinId,
            type = ConceptType.MEDICATION,
            name = "Heparin",
            shortExplanation = "An anticoagulant that prevents blood clots from forming or growing larger — used for DVT/PE treatment and prevention.",
            sections = ConceptSections(
                mechanism = "Potentiates antithrombin III, inactivating thrombin and factor Xa. IV (unfractionated) requires continuous infusion with frequent aPTT monitoring; subcutaneous dosing used for prophylaxis.",
                sideEffects = "Bruising, bleeding, injection site irritation (subQ).",
                adverseEffects = "Heparin-induced thrombocytopenia (HIT) — a serious immune reaction; major bleeding, especially with supratherapeutic aPTT.",
                nursingImplications = "Monitor aPTT (IV) or anti-Xa levels, platelet counts (watch for HIT), signs of bleeding. Have protamine sulfate available as reversal agent."
            ),
            tags = listOf("Pharmacology", "Anticoagulant"),
            sourceCitation = "Source: MedlinePlus"
        )

        ConceptRepository.insert(
            id = warfarinId,
            type = ConceptType.MEDICATION,
            name = "Warfarin",
            shortExplanation = "An oral anticoagulant used for long-term prevention of blood clots, commonly in atrial fibrillation or after a DVT/PE.",
            sections = ConceptSections(
                mechanism = "Inhibits vitamin K-dependent clotting factors (II, VII, IX, X). Requires regular INR monitoring due to a narrow therapeutic window and many drug/food interactions.",
                sideEffects = "Bruising, minor bleeding.",
                adverseEffects = "Major bleeding (GI, intracranial) especially if INR is supratherapeutic; skin necrosis (rare, early therapy).",
                nursingImplications = "Monitor INR regularly, educate on consistent vitamin K intake, watch for interacting medications."
            ),
            tags = listOf("Pharmacology", "Anticoagulant"),
            sourceCitation = "Source: MedlinePlus"
        )

        ConceptRepository.insert(
            id = insulinId,
            type = ConceptType.MEDICATION,
            name = "Insulin",
            shortExplanation = "A hormone that lowers blood glucose by helping cells absorb sugar from the blood — used to manage diabetes and to treat diabetic ketoacidosis (DKA).",
            sections = ConceptSections(
                mechanism = "Rapid-acting forms (e.g. lispro) peak quickly and are short-lived; long-acting forms (e.g. glargine) give steady basal coverage. IV regular insulin is used in DKA for rapid, titratable effect.",
                sideEffects = "Hypoglycemia, injection site reactions, weight gain.",
                adverseEffects = "Severe hypoglycemia (confusion, seizure, loss of consciousness); hypokalemia with IV insulin therapy (drives potassium intracellularly).",
                nursingImplications = "Monitor blood glucose closely, especially with IV infusions; monitor potassium during DKA treatment; know the onset/peak/duration of the specific formulation in use."
            ),
            tags = listOf("Pharmacology", "Endocrine"),
            sourceCitation = "Source: MedlinePlus"
        )

        ConceptRepository.insert(
            id = vancomycinId,
            type = ConceptType.MEDICATION,
            name = "Vancomycin",
            shortExplanation = "A broad-spectrum antibiotic used to treat serious infections, including resistant bacteria — often started empirically while cultures are pending in suspected sepsis.",
            sections = ConceptSections(
                mechanism = "Inhibits bacterial cell wall synthesis; effective against many gram-positive organisms including MRSA. Requires trough-level monitoring for dosing and renal function tracking.",
                sideEffects = "Redness/flushing with rapid infusion (\"red man syndrome\"), phlebitis at the infusion site.",
                adverseEffects = "Nephrotoxicity, ototoxicity, severe infusion reactions if given too quickly.",
                nursingImplications = "Infuse slowly over at least 60 minutes, monitor trough levels and renal function, watch for signs of red man syndrome."
            ),
            tags = listOf("Pharmacology", "Antibiotic"),
            sourceCitation = "Source: MedlinePlus"
        )

        ConceptRepository.insert(
            id = albuterolId,
            type = ConceptType.MEDICATION,
            name = "Albuterol",
            shortExplanation = "A fast-acting inhaled medication that opens the airways to make breathing easier — commonly used during a COPD or asthma flare.",
            sections = ConceptSections(
                mechanism = "Short-acting beta-2 agonist — relaxes bronchial smooth muscle. Onset within minutes, often given via nebulizer or inhaler during acute exacerbations.",
                sideEffects = "Tremor, tachycardia, nervousness.",
                adverseEffects = "Significant tachyarrhythmia in sensitive patients, hypokalemia with frequent dosing.",
                nursingImplications = "Monitor heart rate, especially with frequent/repeated dosing; assess respiratory status before and after administration."
            ),
            tags = listOf("Pharmacology", "Bronchodilator"),
            sourceCitation = "Source: MedlinePlus"
        )

        ConceptRepository.insert(
            id = norepinephrineId,
            type = ConceptType.MEDICATION,
            name = "Norepinephrine",
            shortExplanation = "A medication that raises blood pressure by tightening blood vessels — used when fluids alone aren't maintaining adequate blood pressure, especially in septic shock.",
            sections = ConceptSections(
                mechanism = "Potent alpha-1 agonist (with some beta-1 activity) causing vasoconstriction and increased cardiac contractility. First-line vasopressor in septic shock.",
                sideEffects = "Reflex bradycardia, headache.",
                adverseEffects = "Peripheral/digital ischemia with prolonged or high-dose use, especially with extravasation — should be given via central line when possible; arrhythmia.",
                nursingImplications = "Continuous BP monitoring, ideally via arterial line; assess extremities/IV site for signs of extravasation; titrate to MAP goal per orders."
            ),
            tags = listOf("Pharmacology", "Vasopressor", "Critical Care"),
            sourceCitation = "Source: StatPearls"
        )

        ConceptRepository.insert(
            id = amiodaroneId,
            type = ConceptType.MEDICATION,
            name = "Amiodarone",
            shortExplanation = "An antiarrhythmic medication used to control or convert abnormal heart rhythms, most often atrial fibrillation.",
            sections = ConceptSections(
                mechanism = "Class III antiarrhythmic — prolongs the cardiac action potential, affecting multiple ion channels. Long half-life (weeks); IV loading followed by oral maintenance is common.",
                sideEffects = "Nausea, photosensitivity, injection site phlebitis (IV).",
                adverseEffects = "Pulmonary toxicity, thyroid dysfunction (hyper- or hypothyroidism), liver toxicity, bradycardia/hypotension with IV administration.",
                nursingImplications = "Monitor heart rate/rhythm and blood pressure during IV administration; monitor liver and thyroid function with long-term use."
            ),
            tags = listOf("Pharmacology", "Antiarrhythmic"),
            sourceCitation = "Source: MedlinePlus"
        )

        // --- Procedures ---

        ConceptRepository.insert(
            id = centralLineId,
            type = ConceptType.PROCEDURE,
            name = "Central Line Insertion",
            shortExplanation = "Placement of a catheter into a large central vein for reliable IV access — used for vasopressors, certain medications, or when peripheral access is inadequate.",
            sections = ConceptSections(
                targetConcern = "Need for reliable central venous access, e.g. to safely administer vasopressors in septic shock.",
                whatToMonitor = "Insertion site for bleeding/infection, chest x-ray to confirm placement and rule out pneumothorax, signs of catheter-related bloodstream infection.",
                medicationsUsed = listOf("Local anesthetic", "Norepinephrine (once placed)")
            ),
            tags = listOf("Critical Care", "Procedure"),
            sourceCitation = "Source: StatPearls"
        )

        ConceptRepository.insert(
            id = intubationId,
            type = ConceptType.PROCEDURE,
            name = "Endotracheal Intubation",
            shortExplanation = "Placement of a breathing tube into the trachea to secure the airway and allow mechanical ventilation — used in respiratory failure or when a patient can't protect their own airway.",
            sections = ConceptSections(
                targetConcern = "Respiratory failure or inability to protect the airway.",
                whatToMonitor = "Tube placement (breath sounds, capnography, chest x-ray), oxygen saturation, blood pressure during and after the procedure, signs of accidental extubation.",
                medicationsUsed = listOf("Sedation", "Paralytic agents")
            ),
            tags = listOf("Critical Care", "Procedure"),
            sourceCitation = "Source: StatPearls"
        )

        ConceptRepository.insert(
            id = chestTubeId,
            type = ConceptType.PROCEDURE,
            name = "Chest Tube Placement",
            shortExplanation = "Insertion of a tube into the pleural space to drain air, blood, or fluid and re-expand the lung — commonly used for pneumothorax or significant pleural effusion.",
            sections = ConceptSections(
                targetConcern = "Pneumothorax or large pleural effusion causing respiratory compromise.",
                whatToMonitor = "Drainage amount/color, air leak (bubbling in the water seal chamber), respiratory status, insertion site for bleeding/infection, subcutaneous emphysema.",
                medicationsUsed = listOf("Local anesthetic", "Sedation (if needed)")
            ),
            tags = listOf("Procedure"),
            sourceCitation = "Source: StatPearls"
        )

        // --- Conditions ---

        ConceptRepository.insert(
            id = copdExacerbationId,
            type = ConceptType.CONDITION,
            name = "COPD Exacerbation",
            shortExplanation = "Acute worsening of chronic obstructive pulmonary disease symptoms — increased shortness of breath, cough, and sputum production, often triggered by infection.",
            sections = ConceptSections(
                presentation = "Increased dyspnea, wheezing, increased sputum production or change in sputum color, use of accessory muscles, low oxygen saturation.",
                typicalTreatments = "Bronchodilators (albuterol), corticosteroids, supplemental oxygen, antibiotics if infection is suspected, possibly BiPAP or intubation in severe cases.",
                riskFactors = "Smoking history, respiratory infection, air pollution exposure, poor medication adherence."
            ),
            tags = listOf("Pulmonology"),
            sourceCitation = "Source: MedlinePlus, StatPearls"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), copdExacerbationId, "COPD", "ACRONYM")

        ConceptRepository.insert(
            id = sepsisId,
            type = ConceptType.CONDITION,
            name = "Sepsis",
            shortExplanation = "A life-threatening response to infection that can lead to organ dysfunction and shock if not treated quickly.",
            sections = ConceptSections(
                presentation = "Fever or hypothermia, tachycardia, tachypnea, altered mental status, hypotension in severe cases (septic shock).",
                typicalTreatments = "Broad-spectrum antibiotics, IV fluid resuscitation, vasopressors if hypotension persists, source control of the underlying infection.",
                riskFactors = "Immunosuppression, indwelling catheters/lines, recent surgery, advanced age, chronic illness."
            ),
            tags = listOf("Critical Care", "Infectious Disease"),
            sourceCitation = "Source: MedlinePlus, StatPearls"
        )

        ConceptRepository.insert(
            id = dkaId,
            type = ConceptType.CONDITION,
            name = "Diabetic Ketoacidosis",
            shortExplanation = "A serious complication of diabetes where the body produces high levels of blood acids (ketones) due to insufficient insulin — a medical emergency requiring prompt treatment.",
            sections = ConceptSections(
                presentation = "Hyperglycemia, fruity-smelling breath, nausea/vomiting, abdominal pain, rapid breathing (Kussmaul respirations), altered mental status in severe cases.",
                typicalTreatments = "IV fluids, IV insulin infusion, potassium replacement (insulin drives potassium into cells), correction of the underlying trigger (e.g. infection, missed insulin doses).",
                riskFactors = "Missed insulin doses, infection, new-onset type 1 diabetes, physiologic stress (illness, surgery)."
            ),
            tags = listOf("Endocrine"),
            sourceCitation = "Source: MedlinePlus, StatPearls"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), dkaId, "DKA", "ACRONYM")

        ConceptRepository.insert(
            id = atrialFibrillationId,
            type = ConceptType.CONDITION,
            name = "Atrial Fibrillation",
            shortExplanation = "An irregular, often rapid heart rhythm originating in the atria that increases the risk of stroke and can reduce the heart's pumping efficiency.",
            sections = ConceptSections(
                presentation = "Irregularly irregular pulse, palpitations, fatigue, sometimes asymptomatic and found incidentally on telemetry.",
                typicalTreatments = "Rate control (beta-blockers, amiodarone), rhythm control (antiarrhythmics, cardioversion), anticoagulation (warfarin or other agents) to reduce stroke risk.",
                riskFactors = "Advanced age, hypertension, heart failure, hyperthyroidism, excessive alcohol use."
            ),
            tags = listOf("Cardiology", "Telemetry"),
            sourceCitation = "Source: MedlinePlus, StatPearls"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), atrialFibrillationId, "AFib", "NICKNAME")

        ConceptRepository.insert(
            id = pulmonaryEmbolismId,
            type = ConceptType.CONDITION,
            name = "Pulmonary Embolism",
            shortExplanation = "A blockage in a lung artery, usually caused by a blood clot that traveled from the legs (DVT) — a potentially life-threatening emergency.",
            sections = ConceptSections(
                presentation = "Sudden shortness of breath, chest pain (often pleuritic), tachycardia, low oxygen saturation, sometimes hemoptysis.",
                typicalTreatments = "Anticoagulation (heparin, then often transitioned to an oral anticoagulant), thrombolytics in severe/massive PE, supportive oxygen therapy.",
                riskFactors = "Immobility, recent surgery, DVT history, cancer, pregnancy, clotting disorders."
            ),
            tags = listOf("Pulmonology", "Critical Care"),
            sourceCitation = "Source: MedlinePlus, StatPearls"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), pulmonaryEmbolismId, "PE", "ACRONYM")

        // --- Lab values ---

        ConceptRepository.insert(
            id = troponinId,
            type = ConceptType.LAB_VALUE,
            name = "Troponin",
            shortExplanation = "A protein released into the blood when heart muscle is damaged — the key lab value used to help diagnose a heart attack.",
            sections = ConceptSections(
                normalRange = "Typically <0.04 ng/mL, but the exact cutoff and assay type vary by lab — trended serially rather than interpreted from a single value.",
                abnormalMeaning = "Elevated and rising troponin suggests myocardial injury; the pattern of rise/fall over serial measurements helps distinguish acute injury from other causes of elevation (e.g. renal failure, sepsis)."
            ),
            tags = listOf("Lab values", "Cardiology"),
            sourceCitation = "Source: MedlinePlus"
        )

        ConceptRepository.insert(
            id = inrId,
            type = ConceptType.LAB_VALUE,
            name = "INR",
            shortExplanation = "A standardized measure of how long blood takes to clot — used to monitor and dose warfarin therapy.",
            sections = ConceptSections(
                normalRange = "About 0.8–1.1 without anticoagulation; therapeutic range on warfarin is usually 2.0–3.0 depending on indication.",
                abnormalMeaning = "Too low: inadequate anticoagulation, clot risk. Too high: bleeding risk — may require holding warfarin or reversal with vitamin K."
            ),
            tags = listOf("Lab values"),
            sourceCitation = "Source: MedlinePlus"
        )

        ConceptRepository.insert(
            id = lactateId,
            type = ConceptType.LAB_VALUE,
            name = "Lactate",
            shortExplanation = "A blood marker that rises when tissues aren't getting enough oxygen — trended to gauge severity and response to treatment in sepsis and shock.",
            sections = ConceptSections(
                normalRange = "Typically <2 mmol/L.",
                abnormalMeaning = "Elevated lactate suggests tissue hypoperfusion; a downward trend with treatment suggests improving perfusion, while a persistently high or rising lactate is a poor prognostic sign."
            ),
            tags = listOf("Lab values", "Critical Care"),
            sourceCitation = "Source: MedlinePlus"
        )

        ConceptRepository.insert(
            id = glucoseId,
            type = ConceptType.LAB_VALUE,
            name = "Glucose",
            shortExplanation = "Blood sugar level — closely monitored in patients with diabetes, on insulin therapy, or during critical illness.",
            sections = ConceptSections(
                normalRange = "Roughly 70–100 mg/dL fasting; targets differ for hospitalized/critically ill patients and vary by institution protocol.",
                abnormalMeaning = "Low (hypoglycemia): shakiness, confusion, risk of loss of consciousness if severe. High (hyperglycemia): can indicate poor diabetes control or acute illness stress response; markedly elevated with ketosis suggests DKA."
            ),
            tags = listOf("Lab values", "Endocrine"),
            sourceCitation = "Source: MedlinePlus"
        )

        // --- Protocols ---

        ConceptRepository.insert(
            id = sepsisBundleId,
            type = ConceptType.PROTOCOL,
            name = "Sepsis Bundle",
            shortExplanation = "A standardized set of time-sensitive actions performed when sepsis is suspected, designed to improve survival by acting quickly.",
            sections = ConceptSections(
                triggerCriteria = "Suspected infection plus signs of organ dysfunction or meeting systemic inflammatory criteria, per unit/hospital sepsis screening tool.",
                steps = "Draw blood cultures before antibiotics, measure lactate, start broad-spectrum antibiotics promptly, begin IV fluid resuscitation, reassess and add vasopressors if hypotension persists after fluids."
            ),
            tags = listOf("Critical Care", "Protocol"),
            sourceCitation = "Source: StatPearls"
        )

        // --- Edges ---

        ConceptRepository.insertEdge(UUID.randomUUID(), furosemideId, chfId, "TREATS")
        ConceptRepository.insertEdge(UUID.randomUUID(), furosemideId, loopDiureticsClassId, "IS_A")
        ConceptRepository.insertEdge(UUID.randomUUID(), furosemideId, potassiumLabId, "RELATED_TO")
        ConceptRepository.insertEdge(UUID.randomUUID(), metoprololId, chfId, "TREATS")
        ConceptRepository.insertEdge(UUID.randomUUID(), lisinoprilId, chfId, "TREATS")
        ConceptRepository.insertEdge(UUID.randomUUID(), potassiumChlorideId, furosemideId, "RELATED_TO")
        ConceptRepository.insertEdge(UUID.randomUUID(), potassiumChlorideId, potassiumLabId, "RELATED_TO")

        ConceptRepository.insertEdge(UUID.randomUUID(), heparinId, pulmonaryEmbolismId, "TREATS")
        ConceptRepository.insertEdge(UUID.randomUUID(), warfarinId, atrialFibrillationId, "TREATS")
        ConceptRepository.insertEdge(UUID.randomUUID(), warfarinId, inrId, "RELATED_TO")
        ConceptRepository.insertEdge(UUID.randomUUID(), insulinId, dkaId, "TREATS")
        ConceptRepository.insertEdge(UUID.randomUUID(), insulinId, glucoseId, "RELATED_TO")
        ConceptRepository.insertEdge(UUID.randomUUID(), insulinId, potassiumLabId, "RELATED_TO")
        ConceptRepository.insertEdge(UUID.randomUUID(), vancomycinId, sepsisId, "TREATS")
        ConceptRepository.insertEdge(UUID.randomUUID(), albuterolId, copdExacerbationId, "TREATS")
        ConceptRepository.insertEdge(UUID.randomUUID(), norepinephrineId, sepsisId, "TREATS")
        ConceptRepository.insertEdge(UUID.randomUUID(), amiodaroneId, atrialFibrillationId, "TREATS")
        ConceptRepository.insertEdge(UUID.randomUUID(), metoprololId, atrialFibrillationId, "TREATS")

        ConceptRepository.insertEdge(UUID.randomUUID(), centralLineId, norepinephrineId, "USES")
        ConceptRepository.insertEdge(UUID.randomUUID(), intubationId, copdExacerbationId, "RELATED_TO")

        ConceptRepository.insertEdge(UUID.randomUUID(), glucoseId, dkaId, "RELATED_TO")
        ConceptRepository.insertEdge(UUID.randomUUID(), lactateId, sepsisId, "RELATED_TO")

        ConceptRepository.insertEdge(UUID.randomUUID(), sepsisBundleId, sepsisId, "RELATED_TO")
        ConceptRepository.insertEdge(UUID.randomUUID(), sepsisBundleId, lactateId, "RELATED_TO")
        ConceptRepository.insertEdge(UUID.randomUUID(), sepsisBundleId, vancomycinId, "USES")
        ConceptRepository.insertEdge(UUID.randomUUID(), sepsisBundleId, norepinephrineId, "USES")
    }
}
