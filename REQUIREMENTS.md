# Nursify — Requirements

Living requirements doc. Update as decisions are made; don't let context live only in chat history.

## Vision

A Kotlin Multiplatform app (iOS first, native SwiftUI UI + Apple Watch companion) for nurses that:
1. Captures quick voice/text notes during onboarding/shifts, to revisit later.
2. Uses AI to augment those notes into a well-organized, connected knowledge graph for learning, grounded in trusted sources.
3. Helps nurses quickly understand a patient's chart in the moment — chief complaint + prescribed drugs — via short (layman's) and long (technical) explanations of *why* each medication is prescribed.

Three related but distinct feature areas: **(A) personal learning graph**, **(B) in-the-moment chart lookup**, and onboarding/orientation that personalizes both.

## Platform & stack decisions

> iOS is the primary platform (revised from an earlier Android-first draft). Apple Watch support — dropped early on because Kotlin/KMP's watchOS support is limited — is back in scope as a native Swift companion now that iOS is primary.

| Area | Decision | Rationale |
|---|---|---|
| Primary platform | **iOS first.** Android is a later phase, not dropped. | Kotlin Multiplatform makes adding Android later straightforward once shared logic exists. |
| iOS UI | **Native SwiftUI**, separate Swift codebase (not Compose Multiplatform) | Best platform feel and full access to iOS APIs; most mature/well-supported path for an iOS-first app. UI is written twice long-term (SwiftUI for iOS, Compose for Android later) but each feels fully native. |
| Shared logic | Kotlin Multiplatform (`shared` module) for business logic/data layer, consumed by iOS via a compiled framework | Keeps non-UI logic (models, networking, sync, local cache) in one Kotlin codebase across platforms. Not yet scaffolded — next step after the iOS UI shell. |
| Watch companion | **Native watchOS app (Swift)**, later phase | Apple Watch is back in scope now that iOS is primary. Wear OS deferred/likely dropped given iOS-first priority. |
| Android UI (future phase) | Jetpack Compose | Standard modern Android stack, once Android phase is scheduled |
| Local storage | Platform-native for now (e.g. SwiftData/Core Data on iOS), offline-first; may move into the shared KMP module later | Must work in low-connectivity hospital environments |
| Backend | Kotlin + Ktor | One language end-to-end; backend owns all LLM calls |
| Database | Postgres + `pgvector` | One store for structured graph tables *and* embeddings; avoids standing up a separate graph DB for v1 |
| AI | Claude API, called server-side only | App never holds the API key; backend can rate-limit/cache and is where graph-building logic lives |
| Knowledge corpus (v1) | Open/public sources only: MedlinePlus, CDC, NIH/PubMed abstracts, StatPearls (open-access) | No licensing negotiation needed for MVP. Every AI explanation cites its source. Licensed clinical DBs (Lexicomp, UpToDate, Davis's) considered but deferred — real cost/licensing constraint if revisited later. |

### Project layout
```
nursify/
  REQUIREMENTS.md
  iosApp/          # native SwiftUI app (scaffolded — see iosApp/README.md)
  shared/          # KMP business-logic module (not yet scaffolded)
  backend/         # Ktor backend (not yet scaffolded)
```

## Onboarding / orientation

### Purpose
First-open flow that asks the nurse a few questions about themselves so the app can personalize learning suggestions and content emphasis from the start, rather than starting from a blank/generic state.

### v1 scope
- One question: **specialty/unit type** — e.g. Telemetry, Med-Surg, Oncology, ICU/Critical Care, ER, L&D/Maternity, Pediatrics, NICU, Psych/Behavioral Health, OR/Perioperative, PACU, Renal/Dialysis, Rehab, Home Health/Hospice.
- **Multi-select** — a nurse can float across or work multiple units.
- Fully **editable later** from settings — not a one-time lock-in.
- No other onboarding questions in v1. An experience-level question was raised (see Open questions) but deliberately deferred, not ruled out.

### How it affects the app
- **Personalizes, does not restrict.** Selected specialties bias:
  - Feature A's gap-detection/"what to review next" suggestions (e.g. a telemetry nurse sees cardiac-rhythm concepts suggested more often).
  - Which parts of the curated knowledge corpus get surfaced first in explanations.
- Everything remains fully accessible regardless of selection — a nurse can capture/learn/look up anything, specialty just weights the suggestion ranking.
- Stored as user profile data (`UserProfile.specialties: List<Specialty>`), separate from the note/graph/patient-lookup data — not itself part of the knowledge graph.

## Content taxonomy

Defines what a "concept" in the knowledge graph can actually be. Originally the app leaned heavily on medications; this formalizes the full scope so procedures and abbreviations (e.g. TAVR, post-op shorthand like NPO or POD#1) are first-class, not an afterthought bolted onto the drug model.

### Concept types
Every node in the knowledge graph has a `type`:

| Type | Examples | Notes |
|---|---|---|
| **Medication** | Furosemide, beta-blockers (class), a combination regimen | Existing coverage (Feature A + B). Can represent a single drug, a drug class, or a combo regimen (see Feature B scope). |
| **Procedure** | TAVR, central line insertion, chest tube placement, wound vac change | What it is, why it's done, what nursing care follows it. |
| **Condition / diagnosis** | CHF, COPD, sepsis, DKA, AKI | Disease processes — often the chief-complaint side of a Feature B lookup. |
| **Lab value / diagnostic finding** | Potassium, BNP, troponin, a specific EKG finding | What it measures, normal/abnormal ranges, why it's trended. |
| **Equipment / device** | PICC line, ventilator, telemetry monitor, wound vac | What it does, care/monitoring considerations. |
| **Protocol / order set** | Sepsis bundle, stroke protocol, rapid response criteria | Standard or unit-specific; ties into the "unit-specific protocol representation" open question below. |
| **Anatomy & physiology** | Loop of Henle, cardiac conduction system | Foundational reference underlying the other types. Lowest priority for v1 content population. |

MVP content population prioritizes **Medication, Procedure, Condition, and Abbreviation aliases** (see below) — the categories nurses actually asked for. Lab value, Equipment, Protocol, and Anatomy are supported by the same data model from day one but populated later; this is a content-curation sequencing decision, not a schema limitation.

### Abbreviations & acronyms are aliases, not a separate type
An abbreviation like "TAVR" isn't its own concept — it's an **alias** that resolves to the canonical concept (`Transcatheter Aortic Valve Replacement`, type `Procedure`). Modeling it this way instead of as a standalone entry avoids duplicate/orphaned content for every shorthand variant of the same real-world thing.

- **`Alias`** — an alternate searchable name attached to a `Concept`: abbreviation/acronym (TAVR, NPO, POD#1), brand name (Lasix → Furosemide), or common nickname. Many aliases can point to one concept.
- Search and autocomplete match against both canonical names and aliases. When a query matches an alias, the result shows the expansion inline (e.g. "TAVR → Transcatheter Aortic Valve Replacement") so the nurse learns the expansion immediately, even before opening the concept.
- Brand names already existed informally in concept detail copy (e.g. "Common brand name: Lasix" on the Furosemide screen) — this formalizes that pattern into a queryable field instead of prose buried in the body text.

## Concept detail pages

Every concept, regardless of type, has its own page — reachable via search, category browse, a tag, or as a related-concept link from another concept's page. This is the payoff of modeling procedures/conditions/labs/etc. as first-class graph nodes (see [Content taxonomy](#content-taxonomy)) instead of text-only descriptions: the graph isn't just a data structure, it's how a nurse actually moves through content.

### Common structure (every type)
- Title, type badge, alias line if applicable (e.g. "Also known as: TAVR").
- Tags — each tag is a tappable link to a filtered view of every concept sharing it (same mechanism as the Learn page's category chips).
- Persistent educational disclaimer banner ("educational reference, not clinical decision support" — shown on every page, not a one-time notice).
- Short explanation.
- Related concepts — chips linking to other concept pages via graph edges; tapping one navigates to that concept's own detail page, not just a preview.
- Source citations.

### Type-specific content
Layered on top of the common structure above:

| Type | Additional sections |
|---|---|
| Medication | Mechanism & side effects, nursing implications, common brand name (existing — see Furosemide). |
| Procedure | **What it is & target concern** — what condition/problem the procedure addresses, via a `treats` edge to the relevant Condition concept, rendered inline (e.g. "Treats: Severe aortic stenosis"). **What to monitor** — post-procedure monitoring parameters (vitals, labs, complications to watch for). **Medications typically used** — linked Medication concepts via a `uses` edge, rendered as tappable chips that open those drug pages directly (e.g. TAVR → anticoagulation, sedation reversal agents). |
| Condition | Presentation/signs & symptoms, typical treatments (the reverse of `treats` — which medications/procedures address this condition), risk factors. |
| Lab value | Normal range, what an abnormal high/low indicates, related conditions. |
| Equipment | Purpose, care/monitoring considerations. |
| Protocol | Trigger criteria, steps. |

### New edge type: `uses`
`uses` (Procedure → Medication) captures "this procedure typically involves this medication" — distinct from `treats`, which captures "this addresses that condition." The existing `treats` edge already generalizes cleanly from Medication→Condition to Procedure→Condition, so no new edge type is needed there.

### Navigation model
Every tag, related-concept chip, and inline `treats`/`uses` reference is a live link to that concept's own page. A procedure page's monitoring/medication sections aren't duplicated text — they're graph relationships rendered in place, so updating a drug's info once updates it everywhere it's referenced (a procedure page, a condition's "typical treatments" list, a chart lookup result, etc.).

## Feature A: Personal learning graph

### Capture
- Voice notes via iPhone and, in a later phase, Apple Watch (short memos captured on watch, queued and finished/transcribed on phone via Watch Connectivity).
- Typed notes as an alternative to voice.
- Offline-first: notes queue locally and sync when connectivity returns.
- No assumption about *where* capture happens (bedside vs. break room vs. post-shift) — audio capture works the same regardless of location, so the product doesn't design around one setting over another.

### Privacy guardrail — PHI filter (day-1 MVP requirement)
- This is a personal learning tool, not clinical documentation or decision support.
- **On-device transcription** (e.g. iOS Speech framework in on-device mode) so raw audio/transcript never leaves the phone before PHI screening completes — nothing unfiltered is sent to the backend.
- **PHI screening runs at capture time**, not just as a post-hoc pattern check. Post-hoc regex matching on names/MRNs alone won't catch spoken conversational PHI ("68-year-old in bed 12 with a COPD exacerbation..."), so screening runs against the transcript as part of the capture flow, before sync/upload.
- Detected PHI-like content **flags for review rather than silently auto-redacting** — heuristics will have false positives/negatives, so the nurse reviews and edits before the note is saved/synced.
- In scope for the MVP (Phase 2 capture build), not a later hardening pass.

### AI augmentation
- Transcript cleanup.
- Entity/concept extraction from notes (drugs, conditions, procedures, lab values, protocols, etc.).
- AI-generated plain-language explanations for extracted concepts, grounded via RAG against the curated open-source corpus, with citations.

### Knowledge graph
- **Note** — raw capture (audio ref + transcript, text, timestamp, device, sync state).
- **Concept** — extracted entity with a `type` (see [Content taxonomy](#content-taxonomy)), canonical AI-generated explanation, source citations, and any `Alias` entries (abbreviations/acronyms/brand names).
- **Edge** — typed relationship: `note→concept (mentions)`, `concept→concept (related_to / is_a / treats / contraindicated_with / uses)`. See [Concept detail pages](#concept-detail-pages) for how `treats`/`uses` render as live, navigable content.
- **Tag** — freeform + suggested categories (med-surg, pharm, unit-specific protocol, etc.) — distinct from `Concept.type`, which is the structural taxonomy; tags are looser, user- and specialty-driven labels layered on top.
- Automatic dedupe/merge of near-duplicate concepts (embedding-similarity based — exact strategy TBD).

### Learn page — search, browse & history
The Learn tab is the primary surface for both the personalized suggestion feed (below) and deliberate, on-demand lookup — searching a drug, procedure, or abbreviation the nurse just heard and wants to understand right now. These are different use cases (passive "what should I learn" vs. active "what is this") and the page is structured to serve both without one crowding out the other.

**Layout, top to bottom:**
1. **Search bar** — persistent, always at the top. Autocompletes against concept names *and* aliases across all taxonomy types (medication, procedure, condition, lab value, equipment, protocol). A query matching an alias (e.g. "TAVR") shows the expansion and resolved concept inline in the result, tagged with its type (e.g. "Transcatheter Aortic Valve Replacement — Procedure"). Medication-type results also surface a key-side-effects preview inline (existing behavior), extended to show the most safety-relevant preview line per type where one exists (e.g. a procedure's key post-op watch-fors).
2. **History button** — icon button on/near the search bar, opens the dedicated **Search history** screen (below). Kept as an explicit button rather than buried in a menu since re-finding something you looked up yesterday is a common, fast action.
3. **Category quick-access** — a row of tappable category chips (Medications, Procedures, Conditions, Abbreviations, Lab Values, Equipment, Protocols) for browsing by topic when the nurse doesn't have an exact term in mind, not just free-text search. Tapping a category filters to concepts of that type.
4. **Recent** — a compact, horizontally-scrollable strip of the last handful of concepts viewed, for one-tap re-access without opening full history.
5. **Suggested for you** — the existing personalized suggestion feed (Due for review / New to explore / Specialty focus / etc.), unchanged, positioned below the search/browse area so deliberate lookup always takes visual priority over passive suggestions.

**Search history screen** (opened via the history button):
- Rows of past concept lookups, grouped by day (Today / Yesterday / older — same grouping pattern already used in Capture's note list), each row showing the concept name, its type tag, and a relative timestamp. Tapping a row reopens that concept's detail page.
- Logs *resolved concept views*, not raw typed queries — if a nurse types "furo" and opens Furosemide, the history entry is "Furosemide," not the partial query string. This is more useful to scan later and avoids cluttering history with typos and abandoned partial searches.
- Tapping any search result opens that concept's own page — see [Concept detail pages](#concept-detail-pages).
- "Recent" (item 4 above) is just the most recent few entries from this same history — one underlying log, two surfaces (a quick strip and a full screen).
- Includes a **Clear history** action — this is general medical-knowledge search history (not patient-specific, so it doesn't carry the same PHI stakes as Feature B), but the nurse should still be able to clear it, consistent with the app's overall privacy-conscious posture.

### Learning suggestions
- **ReviewSchedule** — per-concept spaced-repetition state.
- Gap detection over the graph (e.g. "you noted furosemide 3 times but never linked it to fluid balance — review?").
- Full design in [Suggestion engine](#suggestion-engine) below.

## Feature B: Patient chart lookup (chief complaint + medications)

### Purpose
While reviewing a patient's chart, quickly understand *why* each prescribed drug is being given relative to the chief complaint/presenting illness — both to refresh the nurse's own understanding and to prep for explaining it to the patient.

### Input / data entry
- **Manual quick entry only** (v1). Nurse types/selects the chief complaint and picks drugs from a list for the patient in front of them.
- No OCR/photo capture, no EHR integration in v1.
- EHR integration (FHIR API against Epic/Cerner) explicitly deferred — would require a HIPAA Business Associate Agreement and hospital IT/legal involvement. Noted as a possible future phase only.

### Data retention — ephemeral by design
- Nothing patient-specific persists. The combination of "this chief complaint + these drugs for this patient encounter" is **not stored**.
- Only generic, de-identified drug/condition explanations are cached for reuse across patients (e.g. a cached explanation of "furosemide for CHF" is fine to keep; a record of "Patient X got furosemide on 2026-08-11" is not).
- This keeps the feature out of HIPAA/PHI storage territory — nothing patient-identifiable is ever written to disk or backend.

### Output — two-tier explanation per medication
For each prescribed drug, relative to the entered chief complaint:
1. **Short/concise version** — plain layman's terms. Explains *why the patient is taking this* in language suitable for explaining to a patient. **Not** designed to be shown/handed directly to the patient — it's the nurse's own quick reference so they can explain it in their own words. (Revisit if a true patient-facing display mode is wanted later — would raise the bar on reviewing exact AI wording and need a distinct UI mode.)
2. **Long/detailed version** — more technical. Includes mechanism, side effects, **and nursing implications** (labs/vitals to monitor, what to watch for) — not pharmacology-textbook content alone.
- Both versions grounded in the same curated open-source corpus as Feature A, with citations, reasoning about the specific indication (why *this* drug for *this* chief complaint) rather than returning a generic drug monograph.

### Scope — learning tool, not a full formulary
- Not an exhaustive drug reference covering every possible medication. MVP coverage tracks what's actually common/relevant to learning, not completeness.
- When multiple drugs are prescribed together for a single therapeutic purpose/effect (e.g. a combination regimen), they can be represented as one combined concept with its own short/long explanation, rather than requiring separate, isolated coverage of each drug in the combination.

### Feeds the learning graph (de-identified)
- Chart lookups **do** feed into the personal learning graph (Feature A) — in de-identified form only.
- A lookup produces/reinforces a generic `concept→concept` edge (e.g. `furosemide —treats→ CHF`), plus the short/long explanations cached as that concept's content. No patient identifier, encounter, date/time, or chart-specific detail is attached — only the drug↔complaint relationship itself.
- Repeated lookups across different patients with the same complaint/drug pairing strengthen the same graph edge rather than creating duplicate or patient-linked entries.
- Feeds the same gap-detection/spaced-repetition mechanism as Feature A — e.g. a drug↔complaint pairing looked up often but never otherwise reviewed could surface as a suggested learning item.

## Suggestion engine

### Purpose
Turns the passive knowledge graph, spaced-repetition state, and specialty profile into an active "what should I look at next" feed, so nurses don't have to manually notice their own gaps. Powers Feature A's learning suggestions and is fed by Feature B's de-identified chart-lookup edges.

### Inputs (signals)
- Graph structure: concept nodes, edge types/weights, note→concept mention counts.
- **ReviewSchedule**: per-concept spaced-repetition due dates.
- `UserProfile.specialties`: personalization weighting from onboarding.
- Feature B lookup frequency: which de-identified drug↔complaint edges get reinforced often.
- Learn-page search frequency: concepts looked up via deliberate search but never otherwise captured in a note — a nurse repeatedly searching "TAVR" without it showing up elsewhere in their graph is itself a signal.
- Concept "depth": whether a concept has an actual note/explanation attached, or only exists as an edge target/passing mention.

### Suggestion types
1. **Due for review** — spaced-repetition items past due (classic SRS).
2. **Shallow concept gaps** — concepts referenced multiple times (via notes or chart lookups) but never explored in depth (no note attached, only appears as an edge target). This is the "furosemide mentioned 3 times but never linked to fluid balance" case.
3. **Specialty core-concept gaps** — concepts considered foundational for the nurse's selected specialties that don't exist in their graph at all yet. Requires a seed list of foundational concepts per specialty, curated as part of populating the knowledge corpus (Phase 6) — a content task, not just code.
4. **Related-concept expansion** — graph neighbors (via embedding similarity or explicit edges) of a concept the nurse just reviewed/added that aren't yet captured — e.g. after adding furosemide, suggest loop diuretics as a class, potassium wasting, ototoxicity.
5. **Reinforced-by-practice** — Feature B edges hit repeatedly across different (de-identified) chart lookups, signaling real-world relevance worth deeper study even if the nurse hasn't flagged it themselves.

### Ranking
Score each candidate suggestion from a blend of: overdue-ness (SRS), mention/edge frequency, specialty relevance weight, recency of related activity, and gap size (mentioned vs. actually explored). Bucket by type in the UI (e.g. "Due for review" shown separately from "New to explore") rather than one flat ranked list — the types have different urgency semantics and shouldn't compete directly.

### Delivery
- Home screen "Suggested for you" feed, refreshed regularly.
- Not push-notification-heavy by default — a nurse coming off shift shouldn't get spammed. An opt-in periodic (daily/weekly) digest is reasonable; no default push notifications in v1.
- Each suggestion carries a short "why this was suggested" line (templated or LLM-generated) so it doesn't feel like a black box.

### Implementation notes
- Runs backend-side (Ktor) — it operates over the full graph in Postgres/`pgvector` and may call the LLM for "why suggested" text and for semantic related-concept matching (#4).
- Recomputed incrementally when new notes/concepts/edges are added, plus a scheduled recompute (e.g. nightly) to refresh due-for-review and specialty-gap suggestions.

## Roadmap (sequenced, each phase independently shippable)

1. Foundations — repo, data model, privacy/PII guardrail copy, design system. iOS UI shell scaffolded (`iosApp/`, SwiftUI, XcodeGen).
2. Capture MVP (iPhone only) — voice + typed notes, on-device transcription, on-device PHI screening at capture time, local on-device storage, basic list/organize UI. Includes first-open orientation (specialty/unit multi-select, editable later in settings).
3. Shared KMP module — extract business logic/data layer into `shared/` so Android and future platforms can reuse it; iOS consumes it via a compiled framework.
4. Backend + sync — Ktor API, Postgres, auth, note backup/multi-device sync.
5. AI augmentation pipeline — transcript cleanup, concept/entity extraction, plain-language explanations.
6. Curated knowledge RAG — ingest MedlinePlus/CDC/StatPearls, chunk + embed into `pgvector`, ground explanations with citations.
7. Knowledge graph — concept nodes/edges, dedupe/merge, graph browsing UI. Includes `Concept.type` taxonomy and `Alias` model (see Content taxonomy), per-type concept detail page templates (see Concept detail pages), and the Learn page search/category-browse/history UI.
8. Learning suggestions — gap detection + spaced-repetition reminders (see Suggestion engine).
9. Chart lookup (Feature B) — manual chief complaint + drug entry, short/long dual explanations, ephemeral by design.
10. Apple Watch companion — native watchOS app for on-wrist voice capture, synced via Watch Connectivity.
11. Polish — semantic + full-text search, tagging, export.
12. Android phase (future) — Jetpack Compose UI atop the shared KMP module, once iOS is validated.

## Panel feedback (2026-08-11)

Reviewed by four simulated nurse personas of varying experience for realism/workflow gaps.

- **New grad, med-surg (~4mo)** — capture speed must be brutal-fast (sub-5s) or won't be used on top of existing charting burden; Feature B's long version needs nursing implications, not just pharmacology; pushes back on deferring experience-level in onboarding.
- **Telemetry/step-down (6yr)** — real capture likely happens off-unit (break room/post-shift) given hospital phone-use policies; one-drug-at-a-time entry in Feature B too slow for a 5-6 patient assignment, wants bulk entry or reusable complaint+med combos; wants a way to represent unit-specific protocols that generic sources won't cover.
- **ICU/charge nurse (18yr)** — wants a persistent, visually distinct "educational, not clinical decision support" disclaimer on every AI explanation, not just a one-time notice; thinks PHI guardrail needs to catch spoken conversational PHI, not just pattern-match names/MRNs; questions fully-ephemeral Feature B design since it means zero personal lookup history — wants an aggregate, patient-delinked count only.
- **Nurse educator/preceptor (12yr)** — suggestion engine's spaced-repetition approach fits orientation programs well; wants concepts eventually mappable to existing frameworks (NCLEX categories, unit competency checklists, CCRN/CMSRN-style blueprints); also pushes back on deferring experience-level onboarding; asks whether citations will be source links only or quoted excerpts.

**Resolved since this review**: capture-location assumption (doesn't matter, audio capture works anywhere); PHI screening (now a day-1 capture-time requirement, on-device); Feature B long-version content (nursing implications now required). Still open: experience-level onboarding (deferred, not ruled out — see below), bulk/multi-patient entry for Feature B, unit-specific protocol representation, persistent AI-content disclaimer, aggregate lookup history, competency-framework mapping, citation depth.

## Open questions (unresolved)

- **Experience-level onboarding signal**: deferred for now per product decision, revisit later. Two panel personas independently flagged that "layman's terms" and suggestion depth should calibrate to seniority, not just specialty.
- **Bulk/multi-patient entry for Feature B**: one-drug-at-a-time manual entry may be too slow for a full patient assignment — worth a bulk-entry or reusable-combo flow.
- **Unit-specific protocol representation**: how to represent floor/unit-specific order sets and protocols that generic open sources won't cover.
- **Persistent AI-content disclaimer**: whether every AI explanation needs a visually distinct "educational, not clinical decision support" marker, not just a one-time onboarding notice.
- **Feature B lookup history**: fully ephemeral (current design) vs. an aggregate, patient-delinked personal count (e.g. "looked up furosemide 12 times this month") with no encounter-level record.
- **Competency-framework mapping**: whether concepts should eventually map to existing frameworks (NCLEX categories, unit competency checklists, CCRN/CMSRN-style blueprints).
- **Citation depth**: source title/link only vs. quoted excerpt from the source, for both Feature A and Feature B explanations.
- **Backend hosting**: self-hosted (VPS/Fly.io/Cloud Run) vs. managed Postgres (Neon) + Cloud Run.
- **Auth**: solo personal use (simple local/passcode) vs. multi-user from day one.
- **Concept dedup strategy**: exact-match vs. embedding-similarity merge for the learning graph.
- **Local storage tech on iOS**: SwiftData vs. Core Data vs. pushing local persistence into the shared KMP module (e.g. SQLDelight) from the start so Android doesn't need a rewrite later.
- **When to scaffold `shared/` and `backend/`**: now vs. after the iOS UI shell has real screens to wire up.
- **Search history sync & retention**: local-only vs. synced across devices via the backend; whether it should ever expire/auto-prune, beyond the manual "Clear history" action.
- **Content taxonomy population order**: confirm Medication → Procedure → Condition → Abbreviation aliases as the v1 curation priority, with Lab value/Equipment/Protocol/Anatomy deferred — revisit once real usage data shows what nurses actually search for.
