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
        val foleyCatheterId = UUID.randomUUID()
        val ngTubeId = UUID.randomUUID()
        val piccLineId = UUID.randomUUID()
        val arterialLineId = UUID.randomUUID()
        val thoracentesisId = UUID.randomUUID()
        val paracentesisId = UUID.randomUUID()
        val lumbarPunctureId = UUID.randomUUID()
        val hemodialysisId = UUID.randomUUID()
        val cardioversionId = UUID.randomUUID()
        val prbcTransfusionId = UUID.randomUUID()
        val tracheostomyId = UUID.randomUUID()
        val pegTubeId = UUID.randomUUID()
        val pciId = UUID.randomUUID()
        val cardiacAblationId = UUID.randomUUID()
        val pacemakerId = UUID.randomUUID()
        val pericardiocentesisId = UUID.randomUUID()
        val cabgId = UUID.randomUUID()

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

        // --- Cardiac build-out: comprehensive coverage across every category ---
        // Medications
        val aspirinId = UUID.randomUUID()
        val clopidogrelId = UUID.randomUUID()
        val nitroglycerinId = UUID.randomUUID()
        val atorvastatinId = UUID.randomUUID()
        val digoxinId = UUID.randomUUID()
        val diltiazemId = UUID.randomUUID()
        val adenosineId = UUID.randomUUID()
        val epinephrineId = UUID.randomUUID()
        val atropineId = UUID.randomUUID()
        val apixabanId = UUID.randomUUID()
        val dobutamineId = UUID.randomUUID()
        // Procedures
        val defibrillationId = UUID.randomUUID()
        val icdId = UUID.randomUUID()
        val echocardiogramId = UUID.randomUUID()
        val stressTestId = UUID.randomUUID()
        // Conditions
        val acsId = UUID.randomUUID()
        val cardiacTamponadeId = UUID.randomUUID()
        val cardiogenicShockId = UUID.randomUUID()
        val vFibId = UUID.randomUUID()
        val vTachId = UUID.randomUUID()
        val bradycardiaId = UUID.randomUUID()
        val htnCrisisId = UUID.randomUUID()
        val aorticStenosisId = UUID.randomUUID()
        val pericarditisId = UUID.randomUUID()
        val endocarditisId = UUID.randomUUID()
        val cardiacArrestId = UUID.randomUUID()
        // Lab values
        val bnpId = UUID.randomUUID()
        val magnesiumId = UUID.randomUUID()
        val lipidPanelId = UUID.randomUUID()
        val digoxinLevelId = UUID.randomUUID()
        // Equipment
        val telemetryMonitorId = UUID.randomUUID()
        val ecgMachineId = UUID.randomUUID()
        val defibrillatorId = UUID.randomUUID()
        val iabpId = UUID.randomUUID()
        // Protocols
        val aclsId = UUID.randomUUID()
        val stemiProtocolId = UUID.randomUUID()
        val chestPainProtocolId = UUID.randomUUID()
        // Anatomy
        val coronaryArteriesId = UUID.randomUUID()
        val conductionSystemId = UUID.randomUUID()
        val heartValvesId = UUID.randomUUID()
        val heartChambersId = UUID.randomUUID()

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

        // --- Cardiac medications ---

        ConceptRepository.insert(
            id = aspirinId,
            type = ConceptType.MEDICATION,
            name = "Aspirin",
            shortExplanation = "An antiplatelet that makes platelets less sticky — given early in a suspected heart attack and taken long-term to prevent clots in the coronary arteries.",
            sections = ConceptSections(
                mechanism = "Irreversibly inhibits cyclooxygenase (COX-1), blocking thromboxane A2 and reducing platelet aggregation for the life of the platelet. In suspected ACS, a non-enteric 162–325 mg tablet is chewed for rapid absorption.",
                sideEffects = "GI upset, easy bruising, minor bleeding.",
                adverseEffects = "GI bleeding/ulceration, allergic reaction/bronchospasm, Reye syndrome in children with viral illness.",
                nursingImplications = "Have the patient chew (don't swallow whole) in suspected MI for faster onset; assess for bleeding and GI symptoms; ask about aspirin allergy before giving.",
                commonBrandName = "Bayer, Ecotrin. Often written as ASA."
            ),
            tags = listOf("Pharmacology", "Antiplatelet", "Cardiology"),
            sourceCitation = "Source: MedlinePlus"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), aspirinId, "ASA", "ACRONYM")
        ConceptRepository.insertAlias(UUID.randomUUID(), aspirinId, "Acetylsalicylic Acid", "NICKNAME")

        ConceptRepository.insert(
            id = clopidogrelId,
            type = ConceptType.MEDICATION,
            name = "Clopidogrel",
            shortExplanation = "An antiplatelet often paired with aspirin (dual antiplatelet therapy) after a stent or heart attack to keep the coronary arteries from re-clotting.",
            sections = ConceptSections(
                mechanism = "Irreversibly blocks the platelet P2Y12 ADP receptor, inhibiting aggregation. A prodrug activated in the liver — effect is reduced in poor CYP2C19 metabolizers.",
                sideEffects = "Bruising, minor bleeding, GI upset.",
                adverseEffects = "Major bleeding; rarely thrombotic thrombocytopenic purpura (TTP).",
                nursingImplications = "Emphasize adherence after coronary stenting (stopping early risks stent thrombosis); assess for bleeding; note it's usually held several days before surgery per orders.",
                commonBrandName = "Plavix."
            ),
            tags = listOf("Pharmacology", "Antiplatelet", "Cardiology"),
            sourceCitation = "Source: MedlinePlus"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), clopidogrelId, "DAPT", "ACRONYM")

        ConceptRepository.insert(
            id = nitroglycerinId,
            type = ConceptType.MEDICATION,
            name = "Nitroglycerin",
            shortExplanation = "A vasodilator that relieves chest pain (angina) by widening blood vessels and reducing the heart's workload.",
            sections = ConceptSections(
                mechanism = "Releases nitric oxide, relaxing vascular smooth muscle — venodilation lowers preload (the main effect) with some coronary vasodilation. Available sublingual, IV, and topical.",
                sideEffects = "Headache, flushing, dizziness, hypotension.",
                adverseEffects = "Severe hypotension, especially with volume depletion, right-ventricular/inferior MI, or recent PDE-5 inhibitor (e.g. sildenafil) use — a dangerous interaction.",
                nursingImplications = "Check blood pressure before and after each dose; sublingual angina dosing is one tab every 5 minutes up to 3 doses — call for help if pain persists; titrate IV to pain and BP.",
                commonBrandName = "Nitrostat, Nitro-Dur. Often called NTG or \"nitro.\""
            ),
            tags = listOf("Pharmacology", "Vasodilator", "Cardiology"),
            sourceCitation = "Source: MedlinePlus"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), nitroglycerinId, "NTG", "ACRONYM")
        ConceptRepository.insertAlias(UUID.randomUUID(), nitroglycerinId, "SL Nitro", "NICKNAME")

        ConceptRepository.insert(
            id = atorvastatinId,
            type = ConceptType.MEDICATION,
            name = "Atorvastatin",
            shortExplanation = "A statin that lowers cholesterol — used to slow plaque buildup in arteries and reduce the risk of heart attack and stroke.",
            sections = ConceptSections(
                mechanism = "Inhibits HMG-CoA reductase, the rate-limiting enzyme in hepatic cholesterol synthesis, lowering LDL and stabilizing atherosclerotic plaque. High-intensity dosing is standard after ACS.",
                sideEffects = "Muscle aches, GI upset, headache.",
                adverseEffects = "Myopathy/rhabdomyolysis (muscle pain with dark urine), elevated liver enzymes.",
                nursingImplications = "Ask about new muscle pain or weakness; monitor liver function per orders; typically dosed in the evening; counsel to avoid large amounts of grapefruit juice.",
                commonBrandName = "Lipitor."
            ),
            tags = listOf("Pharmacology", "Statin", "Cardiology"),
            sourceCitation = "Source: MedlinePlus"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), atorvastatinId, "Statin", "NICKNAME")

        ConceptRepository.insert(
            id = digoxinId,
            type = ConceptType.MEDICATION,
            name = "Digoxin",
            shortExplanation = "Strengthens the heart's contraction and slows the heart rate — used in some heart failure and atrial fibrillation patients. Has a narrow safety margin.",
            sections = ConceptSections(
                mechanism = "Inhibits the Na-K-ATPase pump, increasing intracellular calcium (positive inotropy) and enhancing vagal tone to slow AV conduction. Narrow therapeutic index — levels and potassium matter.",
                sideEffects = "Nausea, anorexia, visual changes (yellow-green halos), bradycardia.",
                adverseEffects = "Digoxin toxicity — worsened by hypokalemia, hypomagnesemia, and renal impairment — causing dangerous arrhythmias; reversed with digoxin immune Fab.",
                nursingImplications = "Check apical pulse for a full minute and hold for bradycardia (commonly <60) per parameters; monitor potassium, magnesium, and renal function; know signs of toxicity.",
                commonBrandName = "Lanoxin. Often called \"dig.\""
            ),
            tags = listOf("Pharmacology", "Cardiac glycoside", "Cardiology"),
            sourceCitation = "Source: MedlinePlus"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), digoxinId, "Dig", "NICKNAME")

        ConceptRepository.insert(
            id = diltiazemId,
            type = ConceptType.MEDICATION,
            name = "Diltiazem",
            shortExplanation = "A calcium channel blocker used to slow a fast heart rate (e.g. in atrial fibrillation) and lower blood pressure.",
            sections = ConceptSections(
                mechanism = "Non-dihydropyridine calcium channel blocker — slows AV node conduction (rate control) and relaxes vascular smooth muscle. IV for acute rate control, PO for maintenance.",
                sideEffects = "Hypotension, bradycardia, peripheral edema, headache.",
                adverseEffects = "Symptomatic bradycardia or heart block; worsening heart failure in reduced ejection fraction; hypotension with IV use.",
                nursingImplications = "Monitor heart rate and blood pressure closely during IV administration; avoid combining with IV beta-blockers (additive AV block); hold per bradycardia/hypotension parameters.",
                commonBrandName = "Cardizem, Cartia XT."
            ),
            tags = listOf("Pharmacology", "Calcium channel blocker", "Cardiology"),
            sourceCitation = "Source: MedlinePlus"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), diltiazemId, "CCB", "ACRONYM")

        ConceptRepository.insert(
            id = adenosineId,
            type = ConceptType.MEDICATION,
            name = "Adenosine",
            shortExplanation = "A very fast-acting drug that briefly \"pauses\" the heart to break certain rapid rhythms (SVT) and reset a normal beat.",
            sections = ConceptSections(
                mechanism = "Transiently blocks AV node conduction, interrupting reentrant SVT. Extremely short half-life (seconds) — must be given as a rapid IV push followed immediately by a saline flush, ideally at a site close to the heart.",
                sideEffects = "Brief flushing, chest tightness, a sense of impending doom, a short sinus pause — all typically last seconds.",
                adverseEffects = "Transient asystole, bronchospasm in asthmatics, brief high-grade AV block.",
                nursingImplications = "Give as fast IV push with an immediate flush (two-syringe or stopcock technique); warn the patient about the brief uncomfortable feeling; have continuous ECG running and a defibrillator nearby.",
                commonBrandName = "Adenocard."
            ),
            tags = listOf("Pharmacology", "Antiarrhythmic", "Cardiology", "Critical Care"),
            sourceCitation = "Source: StatPearls"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), adenosineId, "SVT", "ACRONYM")

        ConceptRepository.insert(
            id = epinephrineId,
            type = ConceptType.MEDICATION,
            name = "Epinephrine",
            shortExplanation = "A powerful medication that stimulates the heart and blood vessels — a cornerstone drug in cardiac arrest and anaphylaxis.",
            sections = ConceptSections(
                mechanism = "Alpha- and beta-adrenergic agonist — increases heart rate, contractility, and systemic vascular resistance. In cardiac arrest, 1 mg IV/IO every 3–5 minutes per ACLS.",
                sideEffects = "Tachycardia, palpitations, anxiety, tremor, hypertension.",
                adverseEffects = "Tachyarrhythmias, severe hypertension, myocardial ischemia; tissue necrosis with extravasation of concentrated infusions.",
                nursingImplications = "Know the concentration and route — arrest dosing (1 mg of 1:10,000 IV) differs sharply from anaphylaxis dosing (IM); double-check the code-cart dose; monitor rhythm and blood pressure continuously.",
                commonBrandName = "Adrenalin. Often called \"epi.\""
            ),
            tags = listOf("Pharmacology", "Vasopressor", "Cardiology", "Critical Care"),
            sourceCitation = "Source: StatPearls"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), epinephrineId, "Epi", "NICKNAME")

        ConceptRepository.insert(
            id = atropineId,
            type = ConceptType.MEDICATION,
            name = "Atropine",
            shortExplanation = "Speeds up a dangerously slow heart rate by blocking the vagal \"brake\" on the heart — first-line drug for symptomatic bradycardia.",
            sections = ConceptSections(
                mechanism = "Anticholinergic — blocks muscarinic receptors, reducing vagal tone and increasing sinus node firing and AV conduction. ACLS dose is 1 mg IV every 3–5 minutes (max 3 mg) for symptomatic bradycardia.",
                sideEffects = "Dry mouth, blurred vision, urinary retention, tachycardia, flushing.",
                adverseEffects = "Excessive tachycardia worsening myocardial ischemia; confusion/delirium especially in older adults; may be ineffective in high-grade (infranodal) heart block.",
                nursingImplications = "Push rapidly (slow push can paradoxically slow the heart); monitor rhythm and heart rate response; prepare transcutaneous pacing as a backup if atropine fails.",
                commonBrandName = "Generic atropine."
            ),
            tags = listOf("Pharmacology", "Anticholinergic", "Cardiology", "Critical Care"),
            sourceCitation = "Source: StatPearls"
        )

        ConceptRepository.insert(
            id = apixabanId,
            type = ConceptType.MEDICATION,
            name = "Apixaban",
            shortExplanation = "An oral anticoagulant (DOAC) used to prevent strokes in atrial fibrillation and to treat clots — no routine INR monitoring needed, unlike warfarin.",
            sections = ConceptSections(
                mechanism = "Directly inhibits factor Xa. Predictable dosing without routine coagulation monitoring; shorter half-life than warfarin.",
                sideEffects = "Bruising, minor bleeding.",
                adverseEffects = "Major bleeding (GI, intracranial); reversal with andexanet alfa when available.",
                nursingImplications = "Reinforce not to skip doses (short half-life means clot risk returns quickly); assess for bleeding; note dose reductions for age, weight, and renal function; usually held before procedures per orders.",
                commonBrandName = "Eliquis."
            ),
            tags = listOf("Pharmacology", "Anticoagulant", "Cardiology"),
            sourceCitation = "Source: MedlinePlus"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), apixabanId, "DOAC", "ACRONYM")
        ConceptRepository.insertAlias(UUID.randomUUID(), apixabanId, "NOAC", "ACRONYM")

        ConceptRepository.insert(
            id = dobutamineId,
            type = ConceptType.MEDICATION,
            name = "Dobutamine",
            shortExplanation = "An inotrope that strengthens the heart's pumping — used when a weak heart can't maintain adequate output, as in cardiogenic shock or decompensated heart failure.",
            sections = ConceptSections(
                mechanism = "Primarily a beta-1 agonist — increases contractility and cardiac output with modest effect on systemic vascular resistance (can lower blood pressure via beta-2 vasodilation).",
                sideEffects = "Tachycardia, palpitations, mild blood pressure changes.",
                adverseEffects = "Tachyarrhythmias, increased myocardial oxygen demand and ischemia, hypotension.",
                nursingImplications = "Continuous ECG and blood pressure monitoring (ideally arterial line); titrate to hemodynamic goals; watch for arrhythmias and ischemic chest pain.",
                commonBrandName = "Generic dobutamine."
            ),
            tags = listOf("Pharmacology", "Inotrope", "Cardiology", "Critical Care"),
            sourceCitation = "Source: StatPearls"
        )

        // --- Brand-name aliases ---
        // So chart lookup (and search) resolve the brand names nurses actually
        // see on a chart back to the curated generic concept. Furosemide/Lasix
        // is already aliased above. Insulin is intentionally omitted — its
        // brands map to specific formulations, not the generic concept.
        ConceptRepository.insertAlias(UUID.randomUUID(), metoprololId, "Lopressor", "BRAND_NAME")
        ConceptRepository.insertAlias(UUID.randomUUID(), metoprololId, "Toprol-XL", "BRAND_NAME")
        ConceptRepository.insertAlias(UUID.randomUUID(), lisinoprilId, "Zestril", "BRAND_NAME")
        ConceptRepository.insertAlias(UUID.randomUUID(), lisinoprilId, "Prinivil", "BRAND_NAME")
        ConceptRepository.insertAlias(UUID.randomUUID(), potassiumChlorideId, "K-Dur", "BRAND_NAME")
        ConceptRepository.insertAlias(UUID.randomUUID(), potassiumChlorideId, "Klor-Con", "BRAND_NAME")
        ConceptRepository.insertAlias(UUID.randomUUID(), warfarinId, "Coumadin", "BRAND_NAME")
        ConceptRepository.insertAlias(UUID.randomUUID(), warfarinId, "Jantoven", "BRAND_NAME")
        ConceptRepository.insertAlias(UUID.randomUUID(), vancomycinId, "Vancocin", "BRAND_NAME")
        ConceptRepository.insertAlias(UUID.randomUUID(), albuterolId, "Ventolin", "BRAND_NAME")
        ConceptRepository.insertAlias(UUID.randomUUID(), albuterolId, "ProAir", "BRAND_NAME")
        ConceptRepository.insertAlias(UUID.randomUUID(), albuterolId, "Proventil", "BRAND_NAME")
        ConceptRepository.insertAlias(UUID.randomUUID(), norepinephrineId, "Levophed", "BRAND_NAME")
        ConceptRepository.insertAlias(UUID.randomUUID(), amiodaroneId, "Cordarone", "BRAND_NAME")
        ConceptRepository.insertAlias(UUID.randomUUID(), amiodaroneId, "Pacerone", "BRAND_NAME")
        ConceptRepository.insertAlias(UUID.randomUUID(), aspirinId, "Bayer", "BRAND_NAME")
        ConceptRepository.insertAlias(UUID.randomUUID(), aspirinId, "Ecotrin", "BRAND_NAME")
        ConceptRepository.insertAlias(UUID.randomUUID(), clopidogrelId, "Plavix", "BRAND_NAME")
        ConceptRepository.insertAlias(UUID.randomUUID(), nitroglycerinId, "Nitrostat", "BRAND_NAME")
        ConceptRepository.insertAlias(UUID.randomUUID(), nitroglycerinId, "Nitro-Dur", "BRAND_NAME")
        ConceptRepository.insertAlias(UUID.randomUUID(), atorvastatinId, "Lipitor", "BRAND_NAME")
        ConceptRepository.insertAlias(UUID.randomUUID(), digoxinId, "Lanoxin", "BRAND_NAME")
        ConceptRepository.insertAlias(UUID.randomUUID(), diltiazemId, "Cardizem", "BRAND_NAME")
        ConceptRepository.insertAlias(UUID.randomUUID(), diltiazemId, "Cartia XT", "BRAND_NAME")
        ConceptRepository.insertAlias(UUID.randomUUID(), adenosineId, "Adenocard", "BRAND_NAME")
        ConceptRepository.insertAlias(UUID.randomUUID(), epinephrineId, "Adrenalin", "BRAND_NAME")
        ConceptRepository.insertAlias(UUID.randomUUID(), apixabanId, "Eliquis", "BRAND_NAME")

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

        ConceptRepository.insert(
            id = foleyCatheterId,
            type = ConceptType.PROCEDURE,
            name = "Foley Catheter Insertion",
            shortExplanation = "Placement of an indwelling urinary catheter to drain the bladder and allow accurate output monitoring.",
            sections = ConceptSections(
                targetConcern = "Urinary retention, need for precise hourly output monitoring (e.g. in shock or with diuretic therapy), or immobility complicating toileting.",
                whatToMonitor = "Urine color/clarity/amount, signs of catheter-associated UTI (CAUTI), skin integrity around the insertion site, bladder distension if the catheter appears blocked.",
                medicationsUsed = listOf("Lubricant/anesthetic gel")
            ),
            tags = listOf("Med-Surg", "Procedure"),
            sourceCitation = "Source: StatPearls"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), foleyCatheterId, "Urinary Catheter", "NICKNAME")

        ConceptRepository.insert(
            id = ngTubeId,
            type = ConceptType.PROCEDURE,
            name = "Nasogastric Tube Insertion",
            shortExplanation = "Placement of a tube through the nose into the stomach for gastric decompression, medication delivery, or short-term enteral feeding.",
            sections = ConceptSections(
                targetConcern = "Bowel obstruction requiring decompression, inability to take oral intake, or need for short-term enteral nutrition/medication access.",
                whatToMonitor = "Placement confirmation (x-ray and/or aspirate pH), drainage amount/color, nasal and throat skin integrity, aspiration risk during feeds.",
                medicationsUsed = listOf("Topical anesthetic (nasal/throat)")
            ),
            tags = listOf("Med-Surg", "Procedure"),
            sourceCitation = "Source: StatPearls"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), ngTubeId, "NGT", "ACRONYM")

        ConceptRepository.insert(
            id = piccLineId,
            type = ConceptType.PROCEDURE,
            name = "PICC Line Insertion",
            shortExplanation = "Placement of a long catheter through an arm vein that terminates near the heart — used for extended IV access without repeated peripheral sticks.",
            sections = ConceptSections(
                targetConcern = "Need for extended IV access, e.g. multi-week antibiotic courses or medications that irritate peripheral veins.",
                whatToMonitor = "Insertion site for infection/phlebitis, arm swelling or pain (possible thrombosis), catheter tip position confirmed by x-ray.",
                medicationsUsed = listOf("Local anesthetic", "Vancomycin (common indication)")
            ),
            tags = listOf("Med-Surg", "Procedure"),
            sourceCitation = "Source: StatPearls"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), piccLineId, "Peripherally Inserted Central Catheter", "NICKNAME")

        ConceptRepository.insert(
            id = arterialLineId,
            type = ConceptType.PROCEDURE,
            name = "Arterial Line Insertion",
            shortExplanation = "Placement of a catheter into an artery (commonly radial) for continuous blood pressure monitoring and frequent blood draws without repeated needle sticks.",
            sections = ConceptSections(
                targetConcern = "Need for beat-to-beat blood pressure monitoring, e.g. while titrating a vasopressor, or frequent arterial blood gas sampling.",
                whatToMonitor = "Waveform quality, distal perfusion/pulses of the cannulated limb, insertion site for bleeding, accidental disconnection (risk of significant blood loss).",
                medicationsUsed = listOf("Local anesthetic")
            ),
            tags = listOf("Critical Care", "Procedure"),
            sourceCitation = "Source: StatPearls"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), arterialLineId, "A-line", "NICKNAME")

        ConceptRepository.insert(
            id = thoracentesisId,
            type = ConceptType.PROCEDURE,
            name = "Thoracentesis",
            shortExplanation = "Needle drainage of fluid from the space around the lung — done to relieve breathing difficulty or to diagnose the cause of a pleural effusion.",
            sections = ConceptSections(
                targetConcern = "Pleural effusion causing respiratory compromise, or an effusion of unclear cause needing diagnostic sampling.",
                whatToMonitor = "Respiratory status during and after the procedure, signs of pneumothorax (sudden dyspnea, decreased breath sounds), insertion site for bleeding.",
                medicationsUsed = listOf("Local anesthetic")
            ),
            tags = listOf("Pulmonology", "Procedure"),
            sourceCitation = "Source: StatPearls"
        )

        ConceptRepository.insert(
            id = paracentesisId,
            type = ConceptType.PROCEDURE,
            name = "Paracentesis",
            shortExplanation = "Needle drainage of fluid from the abdominal cavity — relieves pressure from ascites and can help identify its cause.",
            sections = ConceptSections(
                targetConcern = "Large-volume ascites causing abdominal distension, discomfort, or respiratory compromise; or ascites of unclear cause needing diagnostic sampling.",
                whatToMonitor = "Vital signs for hypotension from fluid shifts (especially with large-volume taps), insertion site for leakage, need for albumin replacement after large-volume removal.",
                medicationsUsed = listOf("Local anesthetic", "Albumin (with large-volume taps)")
            ),
            tags = listOf("Med-Surg", "Procedure"),
            sourceCitation = "Source: StatPearls"
        )

        ConceptRepository.insert(
            id = lumbarPunctureId,
            type = ConceptType.PROCEDURE,
            name = "Lumbar Puncture",
            shortExplanation = "Needle sampling of cerebrospinal fluid from the lower spine — used to diagnose conditions like meningitis or to relieve elevated pressure around the brain.",
            sections = ConceptSections(
                targetConcern = "Suspected CNS infection (e.g. meningitis) or need to measure/relieve elevated intracranial pressure.",
                whatToMonitor = "Post-procedure headache (positional, from CSF leak), neuro checks, insertion site for bleeding or CSF leakage.",
                medicationsUsed = listOf("Local anesthetic")
            ),
            tags = listOf("Neurology", "Procedure"),
            sourceCitation = "Source: StatPearls"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), lumbarPunctureId, "LP", "ACRONYM")
        ConceptRepository.insertAlias(UUID.randomUUID(), lumbarPunctureId, "Spinal Tap", "NICKNAME")

        ConceptRepository.insert(
            id = hemodialysisId,
            type = ConceptType.PROCEDURE,
            name = "Hemodialysis",
            shortExplanation = "Filters waste, excess fluid, and electrolytes from the blood using an external machine — used when the kidneys can no longer do this on their own.",
            sections = ConceptSections(
                targetConcern = "Acute kidney injury or end-stage renal disease with dangerous fluid overload, electrolyte imbalance, or uremia.",
                whatToMonitor = "Blood pressure during treatment (intradialytic hypotension is common), fluid removal amount versus goal, vascular access site (fistula/graft/catheter) patency and infection signs, post-dialysis electrolytes.",
                medicationsUsed = listOf("Heparin (line/circuit anticoagulation)")
            ),
            tags = listOf("Renal / Dialysis", "Procedure"),
            sourceCitation = "Source: StatPearls"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), hemodialysisId, "HD", "ACRONYM")

        ConceptRepository.insert(
            id = cardioversionId,
            type = ConceptType.PROCEDURE,
            name = "Synchronized Cardioversion",
            shortExplanation = "A timed electrical shock delivered to reset an abnormal heart rhythm back to a normal pattern — used when a fast, unstable rhythm needs to be corrected quickly.",
            sections = ConceptSections(
                targetConcern = "Unstable or persistent symptomatic tachyarrhythmia, commonly atrial fibrillation, that hasn't responded to (or can't wait for) medication alone.",
                whatToMonitor = "Rhythm and pulse immediately before/after, sedation level and airway, skin at pad placement sites, blood pressure.",
                medicationsUsed = listOf("Procedural sedation")
            ),
            tags = listOf("Cardiology", "Critical Care", "Procedure"),
            sourceCitation = "Source: StatPearls"
        )

        ConceptRepository.insert(
            id = prbcTransfusionId,
            type = ConceptType.PROCEDURE,
            name = "Packed Red Blood Cell Transfusion",
            shortExplanation = "Infusion of donor red blood cells to treat significant blood loss or anemia that's causing symptoms or instability.",
            sections = ConceptSections(
                targetConcern = "Symptomatic anemia or acute blood loss where the patient's own red cell count is too low to meet oxygen delivery needs.",
                whatToMonitor = "Vital signs closely (especially the first 15 minutes), signs of transfusion reaction (fever, chills, rash, back pain, dyspnea) — stop the transfusion immediately and notify the provider if suspected.",
                medicationsUsed = listOf("Normal saline (co-administered line)")
            ),
            tags = listOf("Med-Surg", "Critical Care", "Procedure"),
            sourceCitation = "Source: StatPearls"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), prbcTransfusionId, "PRBC", "ACRONYM")
        ConceptRepository.insertAlias(UUID.randomUUID(), prbcTransfusionId, "Blood Transfusion", "NICKNAME")

        ConceptRepository.insert(
            id = tracheostomyId,
            type = ConceptType.PROCEDURE,
            name = "Tracheostomy",
            shortExplanation = "Surgical creation of an airway opening in the neck directly into the trachea — used when a patient needs prolonged mechanical ventilation or has an upper airway obstruction.",
            sections = ConceptSections(
                targetConcern = "Anticipated prolonged mechanical ventilation, or upper airway obstruction that an endotracheal tube can't safely address long-term.",
                whatToMonitor = "Stoma site for bleeding/infection, cuff pressure, secretion volume and suctioning needs, signs of accidental decannulation.",
                medicationsUsed = listOf("Sedation", "Local/general anesthesia")
            ),
            tags = listOf("Critical Care", "Procedure"),
            sourceCitation = "Source: StatPearls"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), tracheostomyId, "Trach", "NICKNAME")

        ConceptRepository.insert(
            id = pegTubeId,
            type = ConceptType.PROCEDURE,
            name = "PEG Tube Placement",
            shortExplanation = "Endoscopic placement of a feeding tube directly through the abdominal wall into the stomach — used when a patient needs long-term enteral nutrition.",
            sections = ConceptSections(
                targetConcern = "Inability to safely swallow or take adequate oral nutrition long-term (e.g. after stroke, in progressive neurologic disease).",
                whatToMonitor = "Stoma site for infection/leakage, tube placement before each feed, feeding tolerance (nausea, distension), skin integrity around the site.",
                medicationsUsed = listOf("Procedural sedation")
            ),
            tags = listOf("Med-Surg", "Procedure"),
            sourceCitation = "Source: StatPearls"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), pegTubeId, "Percutaneous Endoscopic Gastrostomy", "NICKNAME")

        ConceptRepository.insert(
            id = pciId,
            type = ConceptType.PROCEDURE,
            name = "Percutaneous Coronary Intervention",
            shortExplanation = "Threading a catheter through an artery to open a blocked coronary vessel — a balloon widens the narrowing and a stent is usually left behind to hold it open, restoring blood flow to the heart.",
            sections = ConceptSections(
                targetConcern = "A blocked or critically narrowed coronary artery, most urgently in an acute heart attack (STEMI) where fast reperfusion limits heart muscle damage.",
                whatToMonitor = "Access site (radial/femoral) for bleeding or hematoma, distal pulses of the cannulated limb, chest pain and ECG changes (possible re-occlusion or stent thrombosis), renal function after contrast dye.",
                medicationsUsed = listOf("Antiplatelet agents (aspirin, clopidogrel/ticagrelor)", "Heparin", "Contrast dye")
            ),
            tags = listOf("Cardiology", "Critical Care", "Procedure"),
            sourceCitation = "Source: StatPearls"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), pciId, "PCI", "ACRONYM")
        ConceptRepository.insertAlias(UUID.randomUUID(), pciId, "Coronary Angioplasty", "NICKNAME")
        ConceptRepository.insertAlias(UUID.randomUUID(), pciId, "Stent Placement", "NICKNAME")
        ConceptRepository.insertAlias(UUID.randomUUID(), pciId, "Cardiac Catheterization", "NICKNAME")

        ConceptRepository.insert(
            id = cardiacAblationId,
            type = ConceptType.PROCEDURE,
            name = "Cardiac Ablation",
            shortExplanation = "A catheter is guided to the heart to burn (radiofrequency) or freeze (cryo) the small area of tissue causing an abnormal rhythm — destroying the faulty electrical pathway so a normal rhythm can hold.",
            sections = ConceptSections(
                targetConcern = "Recurrent or drug-refractory arrhythmias such as atrial fibrillation, SVT, or ventricular tachycardia originating from an identifiable focus.",
                whatToMonitor = "Access site (usually femoral) for bleeding or hematoma, cardiac rhythm for recurrence or new arrhythmia, signs of cardiac tamponade (hypotension, muffled heart sounds, JVD), distal pulses.",
                medicationsUsed = listOf("Procedural sedation", "Heparin", "Antiarrhythmics")
            ),
            tags = listOf("Cardiology", "Critical Care", "Procedure"),
            sourceCitation = "Source: StatPearls"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), cardiacAblationId, "Catheter Ablation", "NICKNAME")
        ConceptRepository.insertAlias(UUID.randomUUID(), cardiacAblationId, "Heart Cauterization", "NICKNAME")

        ConceptRepository.insert(
            id = pacemakerId,
            type = ConceptType.PROCEDURE,
            name = "Pacemaker Insertion",
            shortExplanation = "Implantation of a small device under the skin with leads into the heart that deliver electrical impulses to keep the heart beating at an adequate rate.",
            sections = ConceptSections(
                targetConcern = "Symptomatic bradycardia, high-grade heart block, or another conduction problem where the heart's own rate is too slow to meet the body's needs.",
                whatToMonitor = "Insertion pocket for bleeding/hematoma or infection, heart rate and rhythm to confirm capture, arm movement restrictions on the implant side, signs of lead dislodgement (hiccups, failure to pace).",
                medicationsUsed = listOf("Local anesthetic", "Procedural sedation")
            ),
            tags = listOf("Cardiology", "Procedure"),
            sourceCitation = "Source: StatPearls"
        )

        ConceptRepository.insert(
            id = pericardiocentesisId,
            type = ConceptType.PROCEDURE,
            name = "Pericardiocentesis",
            shortExplanation = "Needle drainage of fluid from the sac around the heart — relieves pressure that keeps the heart from filling and pumping, most urgently in cardiac tamponade.",
            sections = ConceptSections(
                targetConcern = "Pericardial effusion causing tamponade physiology (hypotension, muffled heart sounds, distended neck veins), or an effusion of unclear cause needing diagnostic sampling.",
                whatToMonitor = "Blood pressure and heart rate for rapid improvement or re-accumulation, ECG changes, insertion site for bleeding, signs of recurring tamponade.",
                medicationsUsed = listOf("Local anesthetic", "Procedural sedation")
            ),
            tags = listOf("Cardiology", "Critical Care", "Procedure"),
            sourceCitation = "Source: StatPearls"
        )

        ConceptRepository.insert(
            id = cabgId,
            type = ConceptType.PROCEDURE,
            name = "Coronary Artery Bypass Graft",
            shortExplanation = "Open-heart surgery that reroutes blood around blocked coronary arteries using a healthy vessel taken from elsewhere in the body — restoring blood supply to heart muscle beyond the blockage.",
            sections = ConceptSections(
                targetConcern = "Severe multi-vessel or left main coronary disease that isn't well suited to stenting, often with angina or reduced heart function.",
                whatToMonitor = "Hemodynamics and cardiac rhythm (arrhythmias are common postoperatively), chest tube output, sternal incision and graft harvest sites for bleeding/infection, respiratory status and pain control, neuro status after bypass.",
                medicationsUsed = listOf("General anesthesia", "Heparin", "Vasopressors/inotropes", "Antiplatelet agents")
            ),
            tags = listOf("Cardiology", "Critical Care", "Procedure"),
            sourceCitation = "Source: StatPearls"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), cabgId, "CABG", "ACRONYM")
        ConceptRepository.insertAlias(UUID.randomUUID(), cabgId, "Heart Bypass Surgery", "NICKNAME")
        ConceptRepository.insertAlias(UUID.randomUUID(), cabgId, "Open-Heart Bypass", "NICKNAME")

        ConceptRepository.insert(
            id = defibrillationId,
            type = ConceptType.PROCEDURE,
            name = "Defibrillation",
            shortExplanation = "An unsynchronized electrical shock delivered to a pulseless, chaotic rhythm (VF or pulseless VT) to stop it and give the heart a chance to restart a normal rhythm.",
            sections = ConceptSections(
                targetConcern = "Ventricular fibrillation or pulseless ventricular tachycardia — a shockable cardiac arrest rhythm requiring immediate defibrillation.",
                whatToMonitor = "Rhythm and pulse immediately after each shock, quality of CPR between shocks, airway and oxygenation, skin at pad sites.",
                medicationsUsed = listOf("Epinephrine", "Amiodarone")
            ),
            tags = listOf("Cardiology", "Critical Care", "Procedure"),
            sourceCitation = "Source: StatPearls"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), defibrillationId, "Defib", "NICKNAME")
        ConceptRepository.insertAlias(UUID.randomUUID(), defibrillationId, "Unsynchronized Cardioversion", "NICKNAME")

        ConceptRepository.insert(
            id = icdId,
            type = ConceptType.PROCEDURE,
            name = "ICD Placement",
            shortExplanation = "Implantation of a device that continuously watches the heart rhythm and delivers a shock automatically if a life-threatening arrhythmia occurs.",
            sections = ConceptSections(
                targetConcern = "High risk of sudden cardiac death — e.g. survived cardiac arrest, reduced ejection fraction, or dangerous ventricular arrhythmias.",
                whatToMonitor = "Implant pocket for bleeding/hematoma or infection, arm movement restrictions on the implant side, device function and any delivered shocks, signs of lead dislodgement.",
                medicationsUsed = listOf("Local anesthetic", "Procedural sedation")
            ),
            tags = listOf("Cardiology", "Procedure"),
            sourceCitation = "Source: StatPearls"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), icdId, "ICD", "ACRONYM")
        ConceptRepository.insertAlias(UUID.randomUUID(), icdId, "Implantable Cardioverter-Defibrillator", "NICKNAME")
        ConceptRepository.insertAlias(UUID.randomUUID(), icdId, "AICD", "ACRONYM")

        ConceptRepository.insert(
            id = echocardiogramId,
            type = ConceptType.PROCEDURE,
            name = "Echocardiogram",
            shortExplanation = "An ultrasound of the heart that shows how well it pumps, how the valves move, and whether there's fluid around it — a painless bedside or lab test.",
            sections = ConceptSections(
                targetConcern = "Need to assess heart function (ejection fraction), valve disease, wall motion after MI, or a pericardial effusion.",
                whatToMonitor = "For a transthoracic study, no special monitoring; for a transesophageal (TEE) study, airway, sedation level, and gag reflex/NPO status before eating.",
                medicationsUsed = listOf("Procedural sedation (TEE only)")
            ),
            tags = listOf("Cardiology", "Procedure"),
            sourceCitation = "Source: StatPearls"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), echocardiogramId, "Echo", "NICKNAME")
        ConceptRepository.insertAlias(UUID.randomUUID(), echocardiogramId, "TTE", "ACRONYM")
        ConceptRepository.insertAlias(UUID.randomUUID(), echocardiogramId, "TEE", "ACRONYM")
        ConceptRepository.insertAlias(UUID.randomUUID(), echocardiogramId, "EF", "ACRONYM")

        ConceptRepository.insert(
            id = stressTestId,
            type = ConceptType.PROCEDURE,
            name = "Cardiac Stress Test",
            shortExplanation = "Monitors the heart while it's made to work harder — by exercise or medication — to reveal blocked coronary arteries that don't cause symptoms at rest.",
            sections = ConceptSections(
                targetConcern = "Suspected coronary artery disease — evaluating exertional chest pain or risk before certain procedures.",
                whatToMonitor = "ECG for ischemic changes, blood pressure and heart rate response, chest pain or shortness of breath — stop the test for significant symptoms or ECG changes.",
                medicationsUsed = listOf("Pharmacologic stress agents (e.g. regadenoson, dobutamine)")
            ),
            tags = listOf("Cardiology", "Procedure"),
            sourceCitation = "Source: StatPearls"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), stressTestId, "Stress Test", "NICKNAME")

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

        // --- Cardiac conditions ---

        ConceptRepository.insert(
            id = acsId,
            type = ConceptType.CONDITION,
            name = "Acute Coronary Syndrome",
            shortExplanation = "A blocked or critically narrowed coronary artery starving heart muscle of oxygen — the umbrella term for unstable angina, NSTEMI, and STEMI (heart attack).",
            sections = ConceptSections(
                presentation = "Chest pressure or pain (often radiating to the arm/jaw), shortness of breath, diaphoresis, nausea; women, older adults, and diabetics may present atypically.",
                typicalTreatments = "Aspirin plus a second antiplatelet, anticoagulation, nitroglycerin, oxygen if hypoxic, statin; emergent cardiac catheterization (PCI) for STEMI; serial troponins and ECGs.",
                riskFactors = "Smoking, hypertension, diabetes, high cholesterol, family history, older age, obesity."
            ),
            tags = listOf("Cardiology", "Critical Care", "Telemetry"),
            sourceCitation = "Source: MedlinePlus, StatPearls"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), acsId, "ACS", "ACRONYM")
        ConceptRepository.insertAlias(UUID.randomUUID(), acsId, "MI", "ACRONYM")
        ConceptRepository.insertAlias(UUID.randomUUID(), acsId, "STEMI", "ACRONYM")
        ConceptRepository.insertAlias(UUID.randomUUID(), acsId, "NSTEMI", "ACRONYM")
        ConceptRepository.insertAlias(UUID.randomUUID(), acsId, "Heart Attack", "NICKNAME")
        ConceptRepository.insertAlias(UUID.randomUUID(), acsId, "Myocardial Infarction", "NICKNAME")

        ConceptRepository.insert(
            id = cardiacTamponadeId,
            type = ConceptType.CONDITION,
            name = "Cardiac Tamponade",
            shortExplanation = "Fluid building up in the sac around the heart squeezes it so it can't fill properly — a life-threatening emergency that drops blood pressure fast.",
            sections = ConceptSections(
                presentation = "Beck's triad (hypotension, muffled heart sounds, distended neck veins), pulsus paradoxus, tachycardia, dyspnea, low-voltage ECG or electrical alternans.",
                typicalTreatments = "Emergent pericardiocentesis or surgical drainage, IV fluids as a temporizing measure to support filling, treat the underlying cause.",
                riskFactors = "Pericarditis, chest trauma, recent cardiac procedure, malignancy, aortic dissection, post-MI wall rupture."
            ),
            tags = listOf("Cardiology", "Critical Care"),
            sourceCitation = "Source: MedlinePlus, StatPearls"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), cardiacTamponadeId, "Tamponade", "NICKNAME")

        ConceptRepository.insert(
            id = cardiogenicShockId,
            type = ConceptType.CONDITION,
            name = "Cardiogenic Shock",
            shortExplanation = "The heart is too weak to pump enough blood to meet the body's needs — organs start to fail from poor perfusion. Most often follows a large heart attack.",
            sections = ConceptSections(
                presentation = "Hypotension, cool/mottled extremities, weak pulses, altered mental status, low urine output, pulmonary congestion, rising lactate.",
                typicalTreatments = "Treat the cause (e.g. urgent revascularization for MI), inotropes (dobutamine), vasopressors, and mechanical support such as an intra-aortic balloon pump in severe cases.",
                riskFactors = "Large myocardial infarction, advanced heart failure, severe arrhythmia, acute valve failure."
            ),
            tags = listOf("Cardiology", "Critical Care"),
            sourceCitation = "Source: MedlinePlus, StatPearls"
        )

        ConceptRepository.insert(
            id = vFibId,
            type = ConceptType.CONDITION,
            name = "Ventricular Fibrillation",
            shortExplanation = "The ventricles quiver chaotically instead of pumping, so there's no effective heartbeat — a form of cardiac arrest that requires immediate CPR and defibrillation.",
            sections = ConceptSections(
                presentation = "Sudden loss of pulse and consciousness; ECG shows disorganized, irregular waveforms with no identifiable QRS complexes.",
                typicalTreatments = "Immediate high-quality CPR and defibrillation (a shockable rhythm), epinephrine and amiodarone per ACLS, and treatment of reversible causes.",
                riskFactors = "Acute MI/ischemia, cardiomyopathy, severe electrolyte imbalance, prolonged QT, prior cardiac arrest."
            ),
            tags = listOf("Cardiology", "Critical Care", "Telemetry"),
            sourceCitation = "Source: StatPearls"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), vFibId, "VF", "ACRONYM")
        ConceptRepository.insertAlias(UUID.randomUUID(), vFibId, "V-Fib", "NICKNAME")

        ConceptRepository.insert(
            id = vTachId,
            type = ConceptType.CONDITION,
            name = "Ventricular Tachycardia",
            shortExplanation = "A fast rhythm arising from the ventricles — it can be stable, or become pulseless and life-threatening. Treatment depends on whether the patient has a pulse and is stable.",
            sections = ConceptSections(
                presentation = "Palpitations, chest pain, shortness of breath, lightheadedness; may deteriorate to loss of pulse. ECG shows a wide-complex, regular, fast rhythm.",
                typicalTreatments = "Pulseless VT: CPR and defibrillation per ACLS. Unstable with a pulse: synchronized cardioversion. Stable: antiarrhythmics such as amiodarone.",
                riskFactors = "Prior MI/scar, cardiomyopathy, electrolyte abnormalities, prolonged QT, structural heart disease."
            ),
            tags = listOf("Cardiology", "Critical Care", "Telemetry"),
            sourceCitation = "Source: StatPearls"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), vTachId, "VT", "ACRONYM")
        ConceptRepository.insertAlias(UUID.randomUUID(), vTachId, "V-Tach", "NICKNAME")

        ConceptRepository.insert(
            id = bradycardiaId,
            type = ConceptType.CONDITION,
            name = "Symptomatic Bradycardia",
            shortExplanation = "A heart rate too slow to meet the body's needs — often from a conduction problem (heart block) — causing dizziness, fatigue, or low blood pressure.",
            sections = ConceptSections(
                presentation = "Heart rate typically <60 with symptoms: lightheadedness, fatigue, syncope, hypotension, chest pain, or shortness of breath. ECG may show sinus bradycardia or AV block.",
                typicalTreatments = "Atropine first-line, transcutaneous pacing if atropine fails, dopamine or epinephrine infusion; permanent pacemaker for persistent high-grade block.",
                riskFactors = "Inferior MI, degenerative conduction disease, medications (beta-blockers, calcium channel blockers, digoxin), hyperkalemia, increased vagal tone."
            ),
            tags = listOf("Cardiology", "Critical Care", "Telemetry"),
            sourceCitation = "Source: StatPearls"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), bradycardiaId, "Heart Block", "NICKNAME")
        ConceptRepository.insertAlias(UUID.randomUUID(), bradycardiaId, "AV Block", "NICKNAME")

        ConceptRepository.insert(
            id = htnCrisisId,
            type = ConceptType.CONDITION,
            name = "Hypertensive Crisis",
            shortExplanation = "Severely elevated blood pressure. When it starts damaging organs (brain, heart, kidneys) it's an emergency needing carefully controlled lowering.",
            sections = ConceptSections(
                presentation = "Very high BP (often >180/120); emergency if with target-organ signs: headache, vision changes, chest pain, shortness of breath, confusion, or neuro deficits.",
                typicalTreatments = "Hypertensive emergency: IV agents (e.g. nicardipine, labetalol) with gradual, controlled BP reduction to avoid hypoperfusion; hypertensive urgency: oral agents and close follow-up.",
                riskFactors = "Poorly controlled or untreated hypertension, medication non-adherence, kidney disease, stimulant use."
            ),
            tags = listOf("Cardiology", "Critical Care"),
            sourceCitation = "Source: MedlinePlus, StatPearls"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), htnCrisisId, "HTN", "ACRONYM")
        ConceptRepository.insertAlias(UUID.randomUUID(), htnCrisisId, "Hypertensive Emergency", "NICKNAME")

        ConceptRepository.insert(
            id = aorticStenosisId,
            type = ConceptType.CONDITION,
            name = "Aortic Stenosis",
            shortExplanation = "The aortic valve narrows and stiffens, forcing the heart to work harder to push blood out — leading to chest pain, fainting, and heart failure as it worsens.",
            sections = ConceptSections(
                presentation = "Exertional chest pain, syncope, and dyspnea; a harsh systolic ejection murmur radiating to the carotids; narrowed pulse pressure in severe disease.",
                typicalTreatments = "Valve replacement when symptomatic or severe — surgical (SAVR) or transcatheter (TAVR); careful management of blood pressure and volume; avoid abrupt vasodilation.",
                riskFactors = "Older age (calcific degeneration), bicuspid aortic valve, rheumatic heart disease, chronic kidney disease."
            ),
            tags = listOf("Cardiology"),
            sourceCitation = "Source: MedlinePlus, StatPearls"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), aorticStenosisId, "AS", "ACRONYM")

        ConceptRepository.insert(
            id = pericarditisId,
            type = ConceptType.CONDITION,
            name = "Pericarditis",
            shortExplanation = "Inflammation of the sac around the heart, causing sharp chest pain that often eases when sitting forward. Usually treatable, but can lead to fluid buildup.",
            sections = ConceptSections(
                presentation = "Sharp, pleuritic chest pain relieved by leaning forward, a pericardial friction rub, and diffuse ST elevation with PR depression on ECG.",
                typicalTreatments = "NSAIDs and colchicine, treat the underlying cause, monitor for progression to a pericardial effusion or tamponade.",
                riskFactors = "Recent viral infection, recent MI (Dressler syndrome), cardiac surgery, autoimmune disease, uremia."
            ),
            tags = listOf("Cardiology"),
            sourceCitation = "Source: MedlinePlus, StatPearls"
        )

        ConceptRepository.insert(
            id = endocarditisId,
            type = ConceptType.CONDITION,
            name = "Infective Endocarditis",
            shortExplanation = "An infection of the heart's inner lining or valves, usually bacterial — dangerous because clumps of infection can break off and travel through the body.",
            sections = ConceptSections(
                presentation = "Fever, new or changed heart murmur, fatigue; classic embolic/immune signs (Janeway lesions, Osler nodes, splinter hemorrhages), positive blood cultures, vegetations on echo.",
                typicalTreatments = "Prolonged IV antibiotics guided by cultures, blood cultures before antibiotics, surgery for valve destruction or persistent infection, monitor for embolic complications.",
                riskFactors = "Prosthetic heart valve, IV drug use, structural heart disease, indwelling lines, prior endocarditis."
            ),
            tags = listOf("Cardiology", "Infectious Disease"),
            sourceCitation = "Source: MedlinePlus, StatPearls"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), endocarditisId, "IE", "ACRONYM")
        ConceptRepository.insertAlias(UUID.randomUUID(), endocarditisId, "Endocarditis", "NICKNAME")

        ConceptRepository.insert(
            id = cardiacArrestId,
            type = ConceptType.CONDITION,
            name = "Cardiac Arrest",
            shortExplanation = "The heart abruptly stops pumping effectively, so blood flow to the brain and body ceases — reversible only with immediate CPR and ACLS.",
            sections = ConceptSections(
                presentation = "Sudden unresponsiveness, no pulse, and no normal breathing (or only gasping). Underlying rhythm may be shockable (VF/pulseless VT) or non-shockable (asystole/PEA).",
                typicalTreatments = "Immediate high-quality CPR, defibrillation for shockable rhythms, epinephrine per ACLS, advanced airway, and identifying/treating reversible causes (the Hs and Ts).",
                riskFactors = "Coronary artery disease/MI, heart failure, severe electrolyte disturbance, hypoxia, drug overdose, prior arrest."
            ),
            tags = listOf("Cardiology", "Critical Care"),
            sourceCitation = "Source: StatPearls"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), cardiacArrestId, "Code Blue", "NICKNAME")
        ConceptRepository.insertAlias(UUID.randomUUID(), cardiacArrestId, "PEA", "ACRONYM")
        ConceptRepository.insertAlias(UUID.randomUUID(), cardiacArrestId, "Asystole", "NICKNAME")

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

        // --- Cardiac lab values ---

        ConceptRepository.insert(
            id = bnpId,
            type = ConceptType.LAB_VALUE,
            name = "BNP",
            shortExplanation = "A hormone released when the heart's chambers are stretched by fluid overload — helps confirm and gauge the severity of heart failure.",
            sections = ConceptSections(
                normalRange = "Typically <100 pg/mL for BNP; NT-proBNP cutoffs are higher and rise with age. Interpreted alongside the clinical picture.",
                abnormalMeaning = "Elevated levels suggest cardiac wall stretch from heart failure/volume overload; higher values generally mean more severe decompensation. Levels can also rise with renal dysfunction and are lower in obesity."
            ),
            tags = listOf("Lab values", "Cardiology"),
            sourceCitation = "Source: MedlinePlus"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), bnpId, "B-type Natriuretic Peptide", "NICKNAME")
        ConceptRepository.insertAlias(UUID.randomUUID(), bnpId, "NT-proBNP", "NICKNAME")

        ConceptRepository.insert(
            id = magnesiumId,
            type = ConceptType.LAB_VALUE,
            name = "Magnesium",
            shortExplanation = "An electrolyte essential for stable heart rhythm and muscle function — low levels raise the risk of dangerous arrhythmias.",
            sections = ConceptSections(
                normalRange = "About 1.7–2.2 mg/dL (varies by lab).",
                abnormalMeaning = "Low (hypomagnesemia): increases arrhythmia risk (including torsades de pointes) and worsens hypokalemia and digoxin toxicity. High (hypermagnesemia): can cause weakness, hypotension, and bradycardia."
            ),
            tags = listOf("Lab values", "Cardiology", "Telemetry"),
            sourceCitation = "Source: MedlinePlus"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), magnesiumId, "Mag", "NICKNAME")
        ConceptRepository.insertAlias(UUID.randomUUID(), magnesiumId, "Mg", "ACRONYM")

        ConceptRepository.insert(
            id = lipidPanelId,
            type = ConceptType.LAB_VALUE,
            name = "Lipid Panel",
            shortExplanation = "A cholesterol blood test used to estimate cardiovascular risk and guide statin therapy — LDL is the main treatment target.",
            sections = ConceptSections(
                normalRange = "LDL is risk-dependent (often a goal <100 mg/dL, or <70 for high-risk patients); HDL >40–50 mg/dL; triglycerides <150 mg/dL.",
                abnormalMeaning = "High LDL and triglycerides with low HDL raise atherosclerotic risk; used to start or intensify statin therapy after events like ACS."
            ),
            tags = listOf("Lab values", "Cardiology"),
            sourceCitation = "Source: MedlinePlus"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), lipidPanelId, "LDL", "ACRONYM")
        ConceptRepository.insertAlias(UUID.randomUUID(), lipidPanelId, "HDL", "ACRONYM")
        ConceptRepository.insertAlias(UUID.randomUUID(), lipidPanelId, "Cholesterol Panel", "NICKNAME")

        ConceptRepository.insert(
            id = digoxinLevelId,
            type = ConceptType.LAB_VALUE,
            name = "Digoxin Level",
            shortExplanation = "A blood level checked to keep digoxin in its narrow safe range — too high risks toxicity and dangerous arrhythmias.",
            sections = ConceptSections(
                normalRange = "Roughly 0.5–2.0 ng/mL, with lower targets (about 0.5–0.9) often preferred in heart failure. Drawn at least 6 hours after the dose.",
                abnormalMeaning = "Elevated levels (worsened by hypokalemia, hypomagnesemia, and renal impairment) point to toxicity — nausea, visual changes, and arrhythmias. Interpret alongside symptoms and potassium."
            ),
            tags = listOf("Lab values", "Cardiology"),
            sourceCitation = "Source: MedlinePlus"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), digoxinLevelId, "Dig Level", "NICKNAME")

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

        // --- Cardiac protocols ---

        ConceptRepository.insert(
            id = aclsId,
            type = ConceptType.PROTOCOL,
            name = "ACLS Cardiac Arrest Algorithm",
            shortExplanation = "The standardized team response to cardiac arrest — high-quality CPR, rhythm checks, shocks for shockable rhythms, and timed medications.",
            sections = ConceptSections(
                triggerCriteria = "Pulseless patient — confirmed cardiac arrest. Rhythm sorted into shockable (VF/pulseless VT) or non-shockable (asystole/PEA).",
                steps = "Start high-quality CPR and attach the monitor/defibrillator. Shockable: defibrillate, resume CPR, give epinephrine every 3–5 min, add amiodarone, shock with each rhythm check. Non-shockable: CPR with epinephrine every 3–5 min. Throughout, search for and treat reversible causes (the Hs and Ts) and minimize interruptions in compressions."
            ),
            tags = listOf("Cardiology", "Critical Care", "Protocol"),
            sourceCitation = "Source: American Heart Association, StatPearls"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), aclsId, "ACLS", "ACRONYM")
        ConceptRepository.insertAlias(UUID.randomUUID(), aclsId, "Code Blue Algorithm", "NICKNAME")

        ConceptRepository.insert(
            id = stemiProtocolId,
            type = ConceptType.PROTOCOL,
            name = "STEMI Protocol",
            shortExplanation = "A time-critical pathway to reopen a blocked coronary artery fast in a full-thickness heart attack — \"time is muscle.\"",
            sections = ConceptSections(
                triggerCriteria = "ST-elevation on a 12-lead ECG with ischemic symptoms — activates the cath lab immediately.",
                steps = "Obtain a 12-lead ECG within 10 minutes of arrival, activate the cath lab, give aspirin and a second antiplatelet plus anticoagulation, manage pain/ischemia, and get the patient to PCI with a door-to-balloon time under 90 minutes (fibrinolytics if timely PCI isn't available)."
            ),
            tags = listOf("Cardiology", "Critical Care", "Protocol"),
            sourceCitation = "Source: American Heart Association, StatPearls"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), stemiProtocolId, "Door-to-Balloon", "NICKNAME")
        ConceptRepository.insertAlias(UUID.randomUUID(), stemiProtocolId, "Cath Lab Activation", "NICKNAME")

        ConceptRepository.insert(
            id = chestPainProtocolId,
            type = ConceptType.PROTOCOL,
            name = "Chest Pain Protocol",
            shortExplanation = "A standardized first response to new chest pain to quickly identify or rule out a heart attack.",
            sections = ConceptSections(
                triggerCriteria = "New or ongoing chest pain or an anginal equivalent (e.g. unexplained dyspnea, especially in higher-risk patients).",
                steps = "Get a 12-lead ECG within 10 minutes, draw troponin (trended serially), apply continuous cardiac monitoring, establish IV access, and consider the initial \"MONA\" measures — aspirin, nitroglycerin, oxygen if hypoxic, and pain control — while escalating to the STEMI pathway if ECG shows ST elevation."
            ),
            tags = listOf("Cardiology", "Telemetry", "Protocol"),
            sourceCitation = "Source: StatPearls"
        )

        // --- Cardiac equipment ---

        ConceptRepository.insert(
            id = telemetryMonitorId,
            type = ConceptType.EQUIPMENT,
            name = "Cardiac Telemetry Monitor",
            shortExplanation = "Continuous wireless heart-rhythm monitoring that lets staff watch for arrhythmias in real time from a central station.",
            sections = ConceptSections(
                purpose = "Continuously track heart rhythm and rate to catch arrhythmias, ischemic changes, or dangerous rate changes early.",
                careConsiderations = "Place and change electrodes on clean, dry skin; know each patient's alarm parameters and respond to alarms (avoid alarm fatigue); ensure leads stay connected and the battery is charged; correlate any rhythm change with the patient's symptoms and a 12-lead ECG."
            ),
            tags = listOf("Cardiology", "Telemetry", "Equipment"),
            sourceCitation = "Source: StatPearls"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), telemetryMonitorId, "Tele", "NICKNAME")
        ConceptRepository.insertAlias(UUID.randomUUID(), telemetryMonitorId, "Cardiac Monitor", "NICKNAME")

        ConceptRepository.insert(
            id = ecgMachineId,
            type = ConceptType.EQUIPMENT,
            name = "12-Lead ECG",
            shortExplanation = "A recording of the heart's electrical activity from 12 angles — the key bedside test for diagnosing a heart attack and identifying arrhythmias.",
            sections = ConceptSections(
                purpose = "Capture a detailed electrical snapshot of the heart to detect ischemia/infarction, arrhythmias, conduction blocks, and electrolyte effects.",
                careConsiderations = "Place limb and precordial leads in correct anatomic positions (misplacement mimics pathology); prep skin for a clean signal; minimize motion artifact; get it within 10 minutes for chest pain and compare with prior tracings."
            ),
            tags = listOf("Cardiology", "Telemetry", "Equipment"),
            sourceCitation = "Source: StatPearls"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), ecgMachineId, "ECG", "ACRONYM")
        ConceptRepository.insertAlias(UUID.randomUUID(), ecgMachineId, "EKG", "ACRONYM")

        ConceptRepository.insert(
            id = defibrillatorId,
            type = ConceptType.EQUIPMENT,
            name = "Defibrillator",
            shortExplanation = "The device that delivers a shock to the heart — used unsynchronized to defibrillate arrest rhythms, or synchronized to cardiovert unstable ones; many also pace.",
            sections = ConceptSections(
                purpose = "Deliver a controlled electrical shock to terminate life-threatening arrhythmias (defibrillation for VF/pulseless VT; synchronized cardioversion for unstable tachyarrhythmias) and provide transcutaneous pacing.",
                careConsiderations = "Ensure pads have good skin contact and clear everyone before discharge (\"I'm clear, you're clear\"); select sync mode for cardioversion but not for defibrillation; keep it charged and checked each shift; remove medication patches and avoid pad placement over an implanted device."
            ),
            tags = listOf("Cardiology", "Critical Care", "Equipment"),
            sourceCitation = "Source: StatPearls"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), defibrillatorId, "AED", "ACRONYM")
        ConceptRepository.insertAlias(UUID.randomUUID(), defibrillatorId, "Crash Cart Defibrillator", "NICKNAME")

        ConceptRepository.insert(
            id = iabpId,
            type = ConceptType.EQUIPMENT,
            name = "Intra-Aortic Balloon Pump",
            shortExplanation = "A balloon in the aorta that inflates and deflates with the heartbeat to boost coronary blood flow and ease the heart's workload — used in severe heart failure or cardiogenic shock.",
            sections = ConceptSections(
                purpose = "Provide temporary mechanical circulatory support — inflating in diastole to improve coronary perfusion and deflating in systole to reduce afterload, increasing cardiac output.",
                careConsiderations = "Verify timing to the cardiac cycle (inflation on the dicrotic notch), keep the affected leg straight and monitor distal pulses/perfusion, watch the insertion site for bleeding, monitor platelets and for limb/renal ischemia, and never let the balloon sit idle (clot risk)."
            ),
            tags = listOf("Cardiology", "Critical Care", "Equipment"),
            sourceCitation = "Source: StatPearls"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), iabpId, "IABP", "ACRONYM")
        ConceptRepository.insertAlias(UUID.randomUUID(), iabpId, "Balloon Pump", "NICKNAME")

        // --- Cardiac anatomy ---

        ConceptRepository.insert(
            id = coronaryArteriesId,
            type = ConceptType.ANATOMY,
            name = "Coronary Arteries",
            shortExplanation = "The vessels that supply the heart muscle itself with oxygen-rich blood — the ones that get blocked in a heart attack.",
            sections = ConceptSections(
                purpose = "Deliver oxygenated blood to the myocardium. The left main branches into the LAD (anterior wall) and circumflex (lateral wall); the right coronary artery (RCA) supplies the inferior wall and, in most people, the SA and AV nodes.",
                careConsiderations = "ECG lead groupings map to territories (inferior II/III/aVF ≈ RCA; anterior V1–V4 ≈ LAD; lateral I/aVL/V5–V6 ≈ circumflex), which helps localize an infarct; RCA involvement often causes bradycardia and heart block."
            ),
            tags = listOf("Cardiology", "Anatomy"),
            sourceCitation = "Source: StatPearls"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), coronaryArteriesId, "LAD", "ACRONYM")
        ConceptRepository.insertAlias(UUID.randomUUID(), coronaryArteriesId, "RCA", "ACRONYM")
        ConceptRepository.insertAlias(UUID.randomUUID(), coronaryArteriesId, "Widow-maker", "NICKNAME")

        ConceptRepository.insert(
            id = conductionSystemId,
            type = ConceptType.ANATOMY,
            name = "Cardiac Conduction System",
            shortExplanation = "The heart's built-in electrical wiring that sets the beat — starting at the SA node and traveling through the AV node to the ventricles.",
            sections = ConceptSections(
                purpose = "Generate and coordinate each heartbeat. The SA node (natural pacemaker) fires, the impulse pauses at the AV node to let the ventricles fill, then travels down the bundle of His and Purkinje fibers to contract the ventricles.",
                careConsiderations = "Where the signal fails maps to the arrhythmia: SA node problems cause bradycardia; AV node/His block causes heart block; abnormal ventricular foci cause VT/VF. This system is the target of pacemakers, ablation, and rate/rhythm drugs."
            ),
            tags = listOf("Cardiology", "Telemetry", "Anatomy"),
            sourceCitation = "Source: StatPearls"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), conductionSystemId, "SA Node", "NICKNAME")
        ConceptRepository.insertAlias(UUID.randomUUID(), conductionSystemId, "AV Node", "NICKNAME")

        ConceptRepository.insert(
            id = heartValvesId,
            type = ConceptType.ANATOMY,
            name = "Heart Valves",
            shortExplanation = "The four one-way valves that keep blood moving in the right direction through the heart — the mitral, tricuspid, aortic, and pulmonic valves.",
            sections = ConceptSections(
                purpose = "Prevent backflow as the heart pumps. The tricuspid and mitral (AV) valves sit between atria and ventricles; the pulmonic and aortic (semilunar) valves guard the outflow to the lungs and body.",
                careConsiderations = "Valves can narrow (stenosis) or leak (regurgitation), each producing a characteristic murmur; severe disease is treated with repair or replacement (surgical or transcatheter, e.g. TAVR); prosthetic valves often require anticoagulation and raise endocarditis risk."
            ),
            tags = listOf("Cardiology", "Anatomy"),
            sourceCitation = "Source: StatPearls"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), heartValvesId, "Mitral Valve", "NICKNAME")
        ConceptRepository.insertAlias(UUID.randomUUID(), heartValvesId, "Aortic Valve", "NICKNAME")

        ConceptRepository.insert(
            id = heartChambersId,
            type = ConceptType.ANATOMY,
            name = "Heart Chambers",
            shortExplanation = "The heart's four rooms — two atria that receive blood and two ventricles that pump it — working as a right and left pump in series.",
            sections = ConceptSections(
                purpose = "Move blood through the body. The right atrium and ventricle receive deoxygenated blood and pump it to the lungs; the left atrium and ventricle receive oxygenated blood and pump it to the body — the left ventricle does the hardest work.",
                careConsiderations = "Right-sided failure shows as systemic congestion (JVD, peripheral edema); left-sided failure shows as pulmonary congestion (crackles, dyspnea); the left ventricle's function is summarized by the ejection fraction."
            ),
            tags = listOf("Cardiology", "Anatomy"),
            sourceCitation = "Source: StatPearls"
        )
        ConceptRepository.insertAlias(UUID.randomUUID(), heartChambersId, "LV", "ACRONYM")
        ConceptRepository.insertAlias(UUID.randomUUID(), heartChambersId, "RV", "ACRONYM")

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
        ConceptRepository.insertEdge(UUID.randomUUID(), piccLineId, vancomycinId, "USES")
        ConceptRepository.insertEdge(UUID.randomUUID(), arterialLineId, norepinephrineId, "RELATED_TO")
        ConceptRepository.insertEdge(UUID.randomUUID(), cardioversionId, atrialFibrillationId, "TREATS")
        ConceptRepository.insertEdge(UUID.randomUUID(), hemodialysisId, potassiumLabId, "RELATED_TO")
        ConceptRepository.insertEdge(UUID.randomUUID(), tracheostomyId, intubationId, "RELATED_TO")

        ConceptRepository.insertEdge(UUID.randomUUID(), glucoseId, dkaId, "RELATED_TO")
        ConceptRepository.insertEdge(UUID.randomUUID(), lactateId, sepsisId, "RELATED_TO")

        ConceptRepository.insertEdge(UUID.randomUUID(), sepsisBundleId, sepsisId, "RELATED_TO")
        ConceptRepository.insertEdge(UUID.randomUUID(), sepsisBundleId, lactateId, "RELATED_TO")
        ConceptRepository.insertEdge(UUID.randomUUID(), sepsisBundleId, vancomycinId, "USES")
        ConceptRepository.insertEdge(UUID.randomUUID(), sepsisBundleId, norepinephrineId, "USES")

        // --- Cardiac edges ---

        // ACS / MI web
        ConceptRepository.insertEdge(UUID.randomUUID(), aspirinId, acsId, "TREATS")
        ConceptRepository.insertEdge(UUID.randomUUID(), clopidogrelId, acsId, "TREATS")
        ConceptRepository.insertEdge(UUID.randomUUID(), nitroglycerinId, acsId, "TREATS")
        ConceptRepository.insertEdge(UUID.randomUUID(), atorvastatinId, acsId, "TREATS")
        ConceptRepository.insertEdge(UUID.randomUUID(), acsId, troponinId, "RELATED_TO")
        ConceptRepository.insertEdge(UUID.randomUUID(), acsId, pciId, "RELATED_TO")
        ConceptRepository.insertEdge(UUID.randomUUID(), acsId, coronaryArteriesId, "RELATED_TO")
        ConceptRepository.insertEdge(UUID.randomUUID(), pciId, acsId, "TREATS")
        ConceptRepository.insertEdge(UUID.randomUUID(), cabgId, acsId, "TREATS")
        ConceptRepository.insertEdge(UUID.randomUUID(), clopidogrelId, pciId, "RELATED_TO")
        ConceptRepository.insertEdge(UUID.randomUUID(), atorvastatinId, lipidPanelId, "RELATED_TO")
        ConceptRepository.insertEdge(UUID.randomUUID(), stemiProtocolId, acsId, "RELATED_TO")
        ConceptRepository.insertEdge(UUID.randomUUID(), stemiProtocolId, pciId, "USES")
        ConceptRepository.insertEdge(UUID.randomUUID(), stemiProtocolId, aspirinId, "USES")
        ConceptRepository.insertEdge(UUID.randomUUID(), stemiProtocolId, ecgMachineId, "USES")
        ConceptRepository.insertEdge(UUID.randomUUID(), chestPainProtocolId, acsId, "RELATED_TO")
        ConceptRepository.insertEdge(UUID.randomUUID(), chestPainProtocolId, troponinId, "USES")
        ConceptRepository.insertEdge(UUID.randomUUID(), chestPainProtocolId, ecgMachineId, "USES")
        ConceptRepository.insertEdge(UUID.randomUUID(), chestPainProtocolId, nitroglycerinId, "USES")

        // Arrest / ACLS web
        ConceptRepository.insertEdge(UUID.randomUUID(), defibrillationId, vFibId, "TREATS")
        ConceptRepository.insertEdge(UUID.randomUUID(), defibrillationId, vTachId, "TREATS")
        ConceptRepository.insertEdge(UUID.randomUUID(), epinephrineId, cardiacArrestId, "TREATS")
        ConceptRepository.insertEdge(UUID.randomUUID(), amiodaroneId, vTachId, "TREATS")
        ConceptRepository.insertEdge(UUID.randomUUID(), amiodaroneId, vFibId, "TREATS")
        ConceptRepository.insertEdge(UUID.randomUUID(), aclsId, cardiacArrestId, "RELATED_TO")
        ConceptRepository.insertEdge(UUID.randomUUID(), aclsId, defibrillationId, "USES")
        ConceptRepository.insertEdge(UUID.randomUUID(), aclsId, epinephrineId, "USES")
        ConceptRepository.insertEdge(UUID.randomUUID(), aclsId, amiodaroneId, "USES")
        ConceptRepository.insertEdge(UUID.randomUUID(), cardiacArrestId, vFibId, "RELATED_TO")
        ConceptRepository.insertEdge(UUID.randomUUID(), cardiacArrestId, vTachId, "RELATED_TO")
        ConceptRepository.insertEdge(UUID.randomUUID(), defibrillatorId, defibrillationId, "USES")
        ConceptRepository.insertEdge(UUID.randomUUID(), defibrillatorId, cardioversionId, "USES")
        ConceptRepository.insertEdge(UUID.randomUUID(), icdId, vFibId, "TREATS")
        ConceptRepository.insertEdge(UUID.randomUUID(), icdId, vTachId, "TREATS")

        // Arrhythmia / rate & rhythm web
        ConceptRepository.insertEdge(UUID.randomUUID(), diltiazemId, atrialFibrillationId, "TREATS")
        ConceptRepository.insertEdge(UUID.randomUUID(), digoxinId, atrialFibrillationId, "TREATS")
        ConceptRepository.insertEdge(UUID.randomUUID(), apixabanId, atrialFibrillationId, "TREATS")
        ConceptRepository.insertEdge(UUID.randomUUID(), cardiacAblationId, atrialFibrillationId, "TREATS")
        ConceptRepository.insertEdge(UUID.randomUUID(), digoxinId, digoxinLevelId, "RELATED_TO")
        ConceptRepository.insertEdge(UUID.randomUUID(), digoxinId, potassiumLabId, "RELATED_TO")
        ConceptRepository.insertEdge(UUID.randomUUID(), magnesiumId, vTachId, "RELATED_TO")
        ConceptRepository.insertEdge(UUID.randomUUID(), atropineId, bradycardiaId, "TREATS")
        ConceptRepository.insertEdge(UUID.randomUUID(), pacemakerId, bradycardiaId, "TREATS")
        ConceptRepository.insertEdge(UUID.randomUUID(), adenosineId, conductionSystemId, "RELATED_TO")
        ConceptRepository.insertEdge(UUID.randomUUID(), bradycardiaId, conductionSystemId, "RELATED_TO")
        ConceptRepository.insertEdge(UUID.randomUUID(), atrialFibrillationId, conductionSystemId, "RELATED_TO")

        // Heart failure / shock web
        ConceptRepository.insertEdge(UUID.randomUUID(), dobutamineId, cardiogenicShockId, "TREATS")
        ConceptRepository.insertEdge(UUID.randomUUID(), dobutamineId, chfId, "TREATS")
        ConceptRepository.insertEdge(UUID.randomUUID(), iabpId, cardiogenicShockId, "TREATS")
        ConceptRepository.insertEdge(UUID.randomUUID(), cardiogenicShockId, acsId, "RELATED_TO")
        ConceptRepository.insertEdge(UUID.randomUUID(), bnpId, chfId, "RELATED_TO")
        ConceptRepository.insertEdge(UUID.randomUUID(), chfId, heartChambersId, "RELATED_TO")
        ConceptRepository.insertEdge(UUID.randomUUID(), echocardiogramId, chfId, "RELATED_TO")
        ConceptRepository.insertEdge(UUID.randomUUID(), echocardiogramId, heartChambersId, "RELATED_TO")

        // Valve / pericardium / vascular web
        ConceptRepository.insertEdge(UUID.randomUUID(), tavrId, aorticStenosisId, "TREATS")
        ConceptRepository.insertEdge(UUID.randomUUID(), aorticStenosisId, heartValvesId, "RELATED_TO")
        ConceptRepository.insertEdge(UUID.randomUUID(), aorticStenosisId, echocardiogramId, "RELATED_TO")
        ConceptRepository.insertEdge(UUID.randomUUID(), pericardiocentesisId, cardiacTamponadeId, "TREATS")
        ConceptRepository.insertEdge(UUID.randomUUID(), cardiacTamponadeId, pericarditisId, "RELATED_TO")
        ConceptRepository.insertEdge(UUID.randomUUID(), endocarditisId, heartValvesId, "RELATED_TO")
        ConceptRepository.insertEdge(UUID.randomUUID(), endocarditisId, vancomycinId, "RELATED_TO")

        // Hypertension web
        ConceptRepository.insertEdge(UUID.randomUUID(), lisinoprilId, htnCrisisId, "TREATS")
        ConceptRepository.insertEdge(UUID.randomUUID(), diltiazemId, htnCrisisId, "TREATS")

        // Diagnostics / monitoring web
        ConceptRepository.insertEdge(UUID.randomUUID(), stressTestId, acsId, "RELATED_TO")
        ConceptRepository.insertEdge(UUID.randomUUID(), ecgMachineId, acsId, "RELATED_TO")
        ConceptRepository.insertEdge(UUID.randomUUID(), ecgMachineId, conductionSystemId, "RELATED_TO")
        ConceptRepository.insertEdge(UUID.randomUUID(), telemetryMonitorId, atrialFibrillationId, "RELATED_TO")
        ConceptRepository.insertEdge(UUID.randomUUID(), telemetryMonitorId, vTachId, "RELATED_TO")
        ConceptRepository.insertEdge(UUID.randomUUID(), coronaryArteriesId, conductionSystemId, "RELATED_TO")
    }
}
