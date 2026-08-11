# Nursify — System Design

Companion to `REQUIREMENTS.md`. That document defines *what* the product does and *why*; this one defines *how* it's built — architecture, data model, service boundaries, sync and AI pipeline design. No implementation yet — this is the design-review pass, reviewed by a simulated panel of a distributed-systems architect, a database/data-modeling expert, a mobile/offline-sync architect, and an AI/ML systems architect (see conversation log / commit message for the panel notes).

Scale framing up front, since it shapes every decision below: this is a **single-user-scale personal app** (multi-user is a stated future phase, not a v1 concern — see `Open questions`). That means the interesting design problems here are correctness, offline-first reliability, and clean data modeling — not horizontal scale, sharding, or high QPS. Resist the urge to over-engineer for scale this product doesn't have yet.

## High-level architecture

```
┌─────────────────┐     ┌──────────────────┐        ┌───────────────────┐
│   iOS App        │     │  watchOS App       │        │  Android App        │
│   (SwiftUI)      │     │  (later phase)     │        │  (later phase)      │
│                  │◄────┤  Watch Connectivity│        │  (Jetpack Compose)  │
│  ┌────────────┐  │     └──────────────────┘        └──────────┬─────────┘
│  │ shared (KMP)│  │                                              │
│  │ - local DB   │  │                                              │
│  │ - sync queue │  │                                              │
│  │ - models     │  │                                              │
│  └──────┬──────┘  │                                              │
└─────────┼─────────┘                                              │
          │  HTTPS (outbox sync, idempotent)                       │
          ▼                                                        ▼
┌───────────────────────────────────────────────────────────────────────┐
│                     Backend — Ktor, modular monolith                   │
│  ┌───────────┐ ┌───────────────┐ ┌────────────┐ ┌───────────────────┐  │
│  │  Sync /    │ │  AI            │ │ Knowledge   │ │  Suggestion        │  │
│  │  Notes API │ │  Augmentation  │ │ Graph API   │ │  Engine            │  │
│  │            │ │  (async worker)│ │ (search,    │ │  (scheduled +      │  │
│  │            │ │                │ │  concepts)  │ │  incremental)      │  │
│  └─────┬─────┘ └───────┬────────┘ └─────┬──────┘ └─────────┬─────────┘  │
│        │               │                 │                   │            │
│  ┌─────┴───────────────┴─────────────────┴───────────────────┴────────┐  │
│  │                     Chart Lookup API (stateless)                    │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────┬──────────────────────────────────────────┘
                                │
                ┌───────────────┴────────────────┐
                ▼                                 ▼
    ┌───────────────────────┐         ┌─────────────────────────┐
    │  Postgres + pgvector    │         │  Claude API (LLM)         │
    │  - graph tables         │         │  + embeddings API         │
    │  - corpus chunks         │         │  (server-side only)       │
    │  - vector indexes        │         └─────────────────────────┘
    └───────────────────────┘
                ▲
                │ (offline batch)
    ┌───────────┴────────────┐
    │  Corpus ingestion job    │
    │  MedlinePlus/CDC/        │
    │  StatPearls → chunk →    │
    │  embed → store           │
    └──────────────────────────┘
```

**Not shown / deliberately absent**: no message queue (Kafka/SQS) — a Postgres-backed job table is sufficient at this scale and is one less system to operate. No API gateway/service mesh — it's one backend service. No separate graph database — `pgvector` + relational tables cover both structured graph queries and semantic search without standing up Neo4j-class infrastructure.

## Data model

Entities below are described conceptually (fields + types + relationships), not as schema/DDL — no code yet, per scope. `PK` = primary key, `FK` = foreign key, `?` = nullable.

### User & profile

**User**
| Field | Type | Notes |
|---|---|---|
| id | uuid, PK | |
| email | text | auth identifier |
| created_at | timestamp | |
| specialties | enum[] | multi-select, from onboarding |
| experience_level | enum | NEW_GRAD / ONE_TO_THREE / FOUR_TO_SEVEN / EIGHT_TO_FIFTEEN / FIFTEEN_PLUS |

Every other table below carries a `user_id` FK, even in the single-user v1 — cheap to add now, expensive to retrofit when multi-user (an open question) actually happens.

### Capture (Feature A)

**Note**
| Field | Type | Notes |
|---|---|---|
| id | uuid, PK | client-generated (idempotency key for sync) |
| user_id | uuid, FK | |
| transcript | text | on-device transcribed before upload |
| device | enum | PHONE / WATCH |
| phi_reviewed | boolean | true once the nurse has cleared the capture-time PHI flag |
| created_at | timestamp | |
| sync_state | enum | PENDING / SYNCING / SYNCED / FAILED — **client-local only**, not meaningful server-side |

Note: raw audio is *not* modeled as a stored artifact here — per the PHI-screening requirement, transcription happens on-device and only the (screened) transcript is what ever leaves the phone. If audio itself is ever retained for playback, that's a client-local file reference, not a backend concern.

### Knowledge graph (Feature A)

**Concept**
| Field | Type | Notes |
|---|---|---|
| id | uuid, PK | |
| type | enum | MEDICATION / PROCEDURE / CONDITION / LAB_VALUE / EQUIPMENT / PROTOCOL / ANATOMY |
| canonical_name | text | indexed (trigram, for autocomplete) |
| short_explanation | text | |
| sections | jsonb | type-specific content — see below |
| embedding | vector | for dedup/similarity, distinct from corpus embeddings |
| created_at / updated_at | timestamp | |

**On `sections` (JSONB) — the one real schema trade-off worth calling out**: the `Content taxonomy` and `Concept detail pages` sections of `REQUIREMENTS.md` define different content per type (a Medication has mechanism/side-effects/adverse-effects/nursing-implications/brand-name; a Procedure has target-concern/monitoring; a Lab value has normal-range; etc). Three ways to model that:
1. **Wide nullable columns** on `Concept` for every possible section — simple to query, but the table gets sparse and every new section type is a migration.
2. **EAV child table** (`ConceptSection: concept_id, section_type, content, order`) — fully flexible, but reconstructing one concept page means an extra join/aggregation for what's the single most common read in the app.
3. **JSONB column** (chosen) — flexible like (2), no join needed for the common "render one concept page" read, Postgres JSONB is indexable/queryable if ever needed. Trade-off: less relational integrity (section keys aren't enforced by the DB), so validate expected keys per `type` at the application layer.

**Alias**
| Field | Type | Notes |
|---|---|---|
| id | uuid, PK | |
| concept_id | uuid, FK | |
| alias_text | text | indexed (trigram) — abbreviation, brand name, or nickname |
| alias_type | enum | ACRONYM / BRAND_NAME / NICKNAME |

**NoteMention** (Note → Concept, split out from `ConceptEdge` — see Marcus's note above)
| Field | Type | Notes |
|---|---|---|
| note_id | uuid, FK | |
| concept_id | uuid, FK | |
| created_at | timestamp | |

**ConceptEdge** (Concept → Concept)
| Field | Type | Notes |
|---|---|---|
| id | uuid, PK | |
| from_concept_id | uuid, FK | |
| to_concept_id | uuid, FK | |
| edge_type | enum | RELATED_TO / IS_A / TREATS / CONTRAINDICATED_WITH / USES |
| weight | int | reinforcement count — incremented on repeat mention/lookup |
| created_at / last_reinforced_at | timestamp | |

**Tag** / **ConceptTag**
| Field | Type | Notes |
|---|---|---|
| Tag.id, Tag.name | uuid, text | e.g. "Telemetry", "Pharmacology" |
| ConceptTag.concept_id, ConceptTag.tag_id | uuid, uuid | many-to-many join |

**ReviewSchedule**
| Field | Type | Notes |
|---|---|---|
| id | uuid, PK | |
| user_id, concept_id | uuid, FK | |
| due_at | timestamp | |
| interval_days | int | SM-2-inspired spaced repetition; exact algorithm is an implementation detail, not designed here |
| ease_factor | float | |
| last_reviewed_at | timestamp | |

**SearchHistoryEntry** (Learn/Search page)
| Field | Type | Notes |
|---|---|---|
| id | uuid, PK | |
| user_id, concept_id | uuid, FK | |
| viewed_at | timestamp | |

Retention: indefinite until the nurse taps "Clear history" (per `REQUIREMENTS.md`) — this one *is* fine to sync, since it's general medical-knowledge browsing, not patient-encounter data.

### Chart lookup (Feature B)

**LookupSession** — **exists only in client-local storage (SQLDelight), never in the Postgres schema.** This is a deliberate exception, not an oversight: per the shift-scoped-history decision, these records carry no patient identifiers by construction, but they're still closer to a real patient encounter than anything else in the app, so they never touch the backend at all — not even encrypted, not even briefly.

| Field | Type | Notes |
|---|---|---|
| id | uuid, PK | |
| chief_complaints | text[] | |
| medication_names | text[] | |
| explanations | json (blob) | the short/long text shown, cached at generation time |
| created_at | timestamp | |
| expires_at | timestamp | `created_at` + ~24h (see open question on the exact window) |

The backend's role in Feature B is purely stateless request/response: given complaints + meds, return grounded explanations (generated fresh or served from the `Concept`/`ConceptEdge` cache below). It never sees or stores a `LookupSession`.

### RAG corpus

**CorpusChunk**
| Field | Type | Notes |
|---|---|---|
| id | uuid, PK | |
| source | enum | MEDLINEPLUS / CDC / PUBMED / STATPEARLS |
| source_url, title | text | for citations |
| chunk_text | text | |
| embedding | vector | distinct index from `Concept.embedding` — different query pattern (top-k retrieval vs. similarity threshold) |
| concept_id | uuid, FK? | nullable — set once a chunk is linked to a canonical concept |

Populated by an offline/batch ingestion job (chunk → embed → store), not part of the live request path — see `REQUIREMENTS.md` roadmap Phase 6.

## API surface (high level — resource groups, not a full spec)

- `POST /notes` — upload a screened transcript; enqueues async augmentation; idempotent on client-generated `Note.id`.
- `GET /concepts/:id` — concept detail page (common structure + type-specific `sections`).
- `GET /concepts/search?q=` — autocomplete, matches `canonical_name` and `Alias.alias_text` (trigram), returns type + inline alias expansion.
- `GET /concepts/category/:type` — category browse.
- `GET /suggestions` — the bucketed suggestion feed.
- `POST /chart-lookup` — stateless; complaints + meds in, short/long explanations out. Nothing persisted server-side.
- `GET /search-history`, `DELETE /search-history` — Learn-page history (this one *is* backend-synced).

## Sync & offline architecture

- **Outbox pattern**: local writes (`Note`s) get a `sync_state`; a background task pushes `PENDING` items when connectivity allows, using the client-generated `id` as an idempotency key so a retried upload after a dropped connection can't create a duplicate note server-side.
- **Low conflict surface by design**: notes are append-only/immutable once captured, and `Concept`/`ConceptEdge` are server-derived rather than user-edited — so this system largely avoids the "two devices edited the same thing" problem that drives most sync-engine complexity. Last-write-wins is sufficient where it matters at all.
- **Local storage**: SQLDelight, inside the KMP `shared` module — the one piece of client logic that's genuinely worth sharing with the future Android build from day one, since local schema/query logic is exactly what shouldn't be written twice.
- **Watch → phone**: Watch Connectivity's background transfer APIs (not the real-time messaging API), so a captured note survives the watch app being backgrounded before the phone receives it.

## AI/ML pipeline architecture

Per-note augmentation is a small state machine, not one synchronous call:
1. Transcript cleanup.
2. Concept/entity extraction + type classification.
3. Embedding generation (dedicated embeddings model, e.g. Voyage AI — not squeezed out of Claude's chat completion) → dedup check against existing `Concept`s.
4. If new: RAG-grounded explanation generation (retrieve `CorpusChunk`s, generate `sections` content with citations).
5. `NoteMention` and `ConceptEdge` creation/reinforcement.

Each step is independently retryable — a failure at step 4 shouldn't force re-running extraction.

**Caching discipline** (cost control): `Concept.sections` content is generated once and reused — the LLM should rarely be called twice for the same canonical concept. Chart Lookup's indication-specific reasoning ("why *this* drug for *this* complaint") is the one genuinely dynamic case, cached per drug×complaint pair rather than per drug alone.

**LLM vs. templated text**: the Suggestion Engine's "why suggested" line defaults to **templated** text wherever it's fully computable from graph state (due-for-review, shallow-gap) — LLM generation is reserved for the genuinely semantic case (related-concept expansion), not used by default everywhere the requirements doc says "templated or LLM-generated."

## Non-functional considerations

- **PHI avoidance is structural, not just policy**: the input UI never collects patient name/MRN/DOB/room number anywhere in the app (Feature A capture screening, Feature B input fields) — so there's nothing for any downstream table, cache, or log to leak. This is why `LookupSession` can safely retain complaint+med text without becoming a PHI-handling system.
- **Security**: token-based auth (JWT or session token) even in single-user v1; TLS in transit; encryption at rest for the backend DB. API key for Claude/embeddings never leaves the backend.
- **Reliability**: offline-first client is the primary reliability mechanism — the app must be fully usable with no connectivity, syncing opportunistically.
- **Cost**: the AI pipeline's caching discipline (above) is the primary cost lever, since LLM calls are the dominant variable cost in this system.

## Open questions from this design pass

- **Multi-user isolation**: schema already carries `user_id` everywhere, but row-level security / tenant isolation enforcement isn't designed yet — fine to defer given the "solo personal use" open question in `REQUIREMENTS.md`, but worth resolving together once multi-user is scheduled.
- **Job queue mechanics**: a Postgres-backed job table is proposed for the async AI pipeline — worth a lightweight spike to confirm polling latency is acceptable before committing, vs. e.g. Postgres `LISTEN/NOTIFY`.
- **`sections` JSONB validation**: application-layer validation of expected keys per `Concept.type` needs an actual owner/mechanism (e.g. a shared Kotlin sealed-class-per-type mapping) so the flexibility of JSONB doesn't quietly become inconsistent data.
- **Embedding model choice**: named Voyage AI as a placeholder recommendation — not evaluated against alternatives yet.
- **Corpus ingestion job schedule**: one-time seed vs. periodic re-sync as source content updates (MedlinePlus/CDC/StatPearls do get revised) isn't decided.
