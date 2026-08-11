# Nursify — Requirements

Living requirements doc. Update as decisions are made; don't let context live only in chat history.

## Vision

A Kotlin Multiplatform app (iOS first, native SwiftUI UI + Apple Watch companion) for nurses that:
1. Captures quick voice/text notes during onboarding/shifts, to revisit later.
2. Uses AI to augment those notes into a well-organized, connected knowledge graph for learning, grounded in trusted sources.
3. Helps nurses quickly understand a patient's chart in the moment — chief complaint + prescribed drugs — via short (layman's) and long (technical) explanations of *why* each medication is prescribed.

Three related but distinct feature areas: **(A) personal learning graph**, **(B) in-the-moment chart lookup**, and onboarding/orientation that personalizes both. Decisions below are tagged accordingly.

## Platform & stack decisions

> **Revised 2026-08-11**: platform priority flipped from Android-first to **iOS-first**. Original Android+Wear OS-only decision (below, struck through in spirit) is superseded. Apple Watch support, originally dropped because Kotlin/KMP watchOS support is limited, is **back in scope** as a later phase since iOS is now primary — it'll be a native Swift watchOS companion, not a KMP target.

| Area | Decision | Rationale |
|---|---|---|
| Primary platform | **iOS first.** Android is a later phase, not dropped. | Reflects updated priority; Kotlin Multiplatform makes adding Android later straightforward once shared logic exists. |
| iOS UI | **Native SwiftUI**, separate Swift codebase (not Compose Multiplatform) | Best platform feel and full access to iOS APIs; most mature/well-supported path for an iOS-first app. Means UI is written twice long-term (SwiftUI for iOS, Compose for Android) but each feels fully native. |
| Shared logic | Kotlin Multiplatform (`shared` module) for business logic/data layer, consumed by iOS via a compiled framework | Keeps non-UI logic (models, networking, sync, local cache) in one Kotlin codebase across platforms; not yet scaffolded — next step after the iOS UI shell. |
| Watch companion | **Native watchOS app (Swift)**, later phase | Apple Watch is back in scope now that iOS is primary. Wear OS is deferred/likely dropped given iOS-first priority — revisit only if Android phone support is prioritized later. |
| Android UI (future phase) | Jetpack Compose | Standard modern Android stack, once Android phase is scheduled |
| Local storage | Platform-native for now (e.g. SwiftData/Core Data on iOS), offline-first; may move into the shared KMP module later | Must work in low-connectivity hospital environments |
| Backend | Kotlin + Ktor | One language end-to-end; backend owns all LLM calls |
| Database | Postgres + `pgvector` | One store for structured graph tables *and* embeddings; avoids standing up a separate graph DB for v1 |
| AI | Claude API, called server-side only | App never holds the API key; backend can rate-limit/cache and is where graph-building logic lives |
| Knowledge corpus (v1) | Open/public sources only: MedlinePlus, CDC, NIH/PubMed abstracts, StatPearls (open-access) | No licensing negotiation needed for MVP. Every AI explanation should cite its source. Licensed clinical DBs (Lexicomp, UpToDate, Davis's) considered but deferred — real cost/licensing constraint if revisited later. |

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
- No other onboarding questions in v1 (e.g. experience level considered, deferred — revisit if a real personalization need shows up).

### How it affects the app
- **Personalizes, does not restrict.** Selected specialties bias:
  - Feature A's gap-detection/"what to review next" suggestions (e.g. a telemetry nurse sees cardiac-rhythm concepts suggested more often).
  - Which parts of the curated knowledge corpus get surfaced first in explanations.
- Everything remains fully accessible regardless of selection — a nurse can capture/learn/look up anything, specialty just weights the suggestion ranking.
- Stored as user profile data (`UserProfile.specialties: List<Specialty>`), separate from the note/graph/patient-lookup data — not itself part of the knowledge graph.

## Feature A: Personal learning graph

### Capture
- Voice notes via iPhone and, in a later phase, Apple Watch (short memos captured on watch, queued and finished/transcribed on phone via Watch Connectivity).
- Typed notes as an alternative to voice.
- Offline-first: notes queue locally and sync when connectivity returns.

### AI augmentation
- Transcript cleanup.
- Entity/concept extraction from notes (drugs, conditions, procedures, lab values, protocols, etc.).
- AI-generated plain-language explanations for extracted concepts, grounded via RAG against the curated open-source corpus, with citations.

### Knowledge graph
- **Note** — raw capture (audio ref + transcript, text, timestamp, device, sync state).
- **Concept** — extracted entity with canonical AI-generated explanation + source citations.
- **Edge** — typed relationship: `note→concept (mentions)`, `concept→concept (related_to / is_a / treats / contraindicated_with)`.
- **Tag** — freeform + suggested categories (med-surg, pharm, unit-specific protocol, etc.).
- Automatic dedupe/merge of near-duplicate concepts (embedding-similarity based — exact strategy TBD).

### Learning suggestions
- **ReviewSchedule** — per-concept spaced-repetition state.
- Gap detection over the graph (e.g. "you noted furosemide 3 times but never linked it to fluid balance — review?").
- Full design in [Suggestion engine](#suggestion-engine) below.

### Privacy guardrail
- This is a personal learning tool, not clinical documentation or decision support.
- Persistent reminder + lightweight on-device pattern check (names, MRNs, room numbers) before any note content uploads — patient-identifiable info should not enter the learning graph at all.

## Feature B: Patient chart lookup (chief complaint + medications)

### Purpose
While reviewing a patient's chart, quickly understand *why* each prescribed drug is being given relative to the chief complaint/presenting illness — both to refresh the nurse's own understanding and to prep for explaining it to the patient.

### Input / data entry
- **Manual quick entry only** (v1). Nurse types/selects the chief complaint and picks drugs from a list for the patient in front of them.
- No OCR/photo capture, no EHR integration in v1.
- EHR integration (FHIR API against Epic/Cerner) explicitly deferred — would require a HIPAA Business Associate Agreement and hospital IT/legal involvement. Not designed for now; noted as a possible future phase only.

### Data retention — ephemeral by design
- Nothing patient-specific persists. The combination of "this chief complaint + these drugs for this patient encounter" is **not stored**.
- Only generic, de-identified drug/condition explanations are cached for reuse across patients (e.g. a cached explanation of "furosemide for CHF" is fine to keep; a record of "Patient X got furosemide on 2026-08-11" is not).
- This keeps the feature out of HIPAA/PHI storage territory — nothing patient-identifiable is ever written to disk or backend.

### Output — two-tier explanation per medication
For each prescribed drug, relative to the entered chief complaint:
1. **Short/concise version** — plain layman's terms. Explains *why the patient is taking this* in language suitable for explaining to a patient. **Not** designed to be shown/handed directly to the patient — it's the nurse's own quick reference so they can explain it in their own words. (Revisit if a true patient-facing display mode is wanted later — would raise the bar on reviewing exact AI wording and need a distinct UI mode.)
2. **Long/detailed version** — more technical. Includes side effects, mechanism, and relevant clinical detail. For the nurse's own deeper understanding.
- Both versions should be grounded in the same curated open-source corpus as Feature A, with citations, and should reason about the specific indication (why *this* drug for *this* chief complaint), not just return a generic drug monograph.

### Feeds the learning graph (de-identified)
- Chart lookups **do** feed into the personal learning graph (Feature A) — in de-identified form only.
- A lookup produces/reinforces a generic `concept→concept` edge (e.g. `furosemide —treats→ CHF`), plus the short/long explanations cached as that concept's content. No patient identifier, encounter, date/time, or chart-specific detail is attached to the edge — only the drug↔complaint relationship itself.
- This means repeated lookups across different patients with the same complaint/drug pairing strengthen the same graph edge rather than creating duplicate or patient-linked entries.
- Feeds the same gap-detection/spaced-repetition mechanism as Feature A — e.g. a drug↔complaint pairing looked up often but never otherwise reviewed could surface as a suggested learning item.

## Suggestion engine

### Purpose
Turns the passive knowledge graph, spaced-repetition state, and specialty profile into an active "what should I look at next" feed, so nurses don't have to manually notice their own gaps. Powers Feature A's learning suggestions and is fed by Feature B's de-identified chart-lookup edges.

### Inputs (signals)
- Graph structure: concept nodes, edge types/weights, note→concept mention counts.
- **ReviewSchedule**: per-concept spaced-repetition due dates.
- `UserProfile.specialties`: personalization weighting from onboarding.
- Feature B lookup frequency: which de-identified drug↔complaint edges get reinforced often.
- Concept "depth": whether a concept has an actual note/explanation attached, or only exists as an edge target/passing mention.

### Suggestion types
1. **Due for review** — spaced-repetition items past due (classic SRS).
2. **Shallow concept gaps** — concepts referenced multiple times (via notes or chart lookups) but never explored in depth (no note attached, only appears as an edge target). This is the "furosemide mentioned 3 times but never linked to fluid balance" case.
3. **Specialty core-concept gaps** — concepts considered foundational for the nurse's selected specialties that don't exist in their graph at all yet. Requires a seed list of foundational concepts per specialty, curated as part of populating the knowledge corpus (see Phase 6) — a content task, not just code.
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
2. Capture MVP (iPhone only) — voice + typed notes, local on-device storage, basic list/organize UI. Includes first-open orientation (specialty/unit multi-select, editable later in settings).
3. Shared KMP module — extract business logic/data layer into `shared/` so Android and future platforms can reuse it; iOS consumes it via a compiled framework.
4. Backend + sync — Ktor API, Postgres, auth, note backup/multi-device sync.
5. AI augmentation pipeline — transcript cleanup, concept/entity extraction, plain-language explanations.
6. Curated knowledge RAG — ingest MedlinePlus/CDC/StatPearls, chunk + embed into `pgvector`, ground explanations with citations.
7. Knowledge graph — concept nodes/edges, dedupe/merge, graph browsing UI.
8. Learning suggestions — gap detection + spaced-repetition reminders (see Suggestion engine).
9. Chart lookup (Feature B) — manual chief complaint + drug entry, short/long dual explanations, ephemeral by design.
10. Apple Watch companion — native watchOS app for on-wrist voice capture, synced via Watch Connectivity.
11. Polish — semantic + full-text search, tagging, export.
12. Android phase (future) — Jetpack Compose UI atop the shared KMP module, once iOS is validated.

## Open questions (unresolved)

- **Backend hosting**: self-hosted (VPS/Fly.io/Cloud Run) vs. managed Postgres (Neon) + Cloud Run.
- **Auth**: solo personal use (simple local/passcode) vs. multi-user from day one.
- **Concept dedup strategy**: exact-match vs. embedding-similarity merge for the learning graph.
- **Local storage tech on iOS**: SwiftData vs. Core Data vs. pushing local persistence into the shared KMP module (e.g. SQLDelight) from the start so Android doesn't need a rewrite later.
- **When to scaffold `shared/` and `backend/`**: now vs. after the iOS UI shell has real screens to wire up.
