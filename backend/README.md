# backend

Kotlin + Ktor backend per `SYSTEM_DESIGN.md` — a modular monolith, not microservices. This first increment covers the Knowledge Graph read API, a stateless Chart Lookup endpoint, note ingestion (persist-only, no AI pipeline yet), and search history. It's been built and run end-to-end against a real Postgres — see "Verified" below.

## Run locally

Requires Docker (used here instead of a local JDK/Gradle install), or a local JDK 21 + this repo's Gradle wrapper.

```sh
# 1. Start Postgres
docker compose up -d

# 2. Run the server (uses the Gradle wrapper)
./gradlew run
```

Server listens on `:8080`. Environment variables (all optional, default to the `docker-compose.yml` values): `DATABASE_URL`, `DATABASE_USER`, `DATABASE_PASSWORD`, `PORT`.

On first boot it seeds 28 hand-curated concepts (`SeedData.kt`) — the original 8 also exist in `iosApp/iosApp/MockData.swift`; the rest (heparin, warfarin, insulin, vancomycin, sepsis, DKA, AFib, PE, COPD exacerbation, troponin, INR, lactate, the sepsis bundle protocol, etc.) are backend-only now that iOS fetches live content over the network instead of needing everything duplicated into Swift too. **Deleting the Postgres volume re-seeds on next boot** (`docker compose down -v`) — a stale volume from an old seed run will silently skip reseeding, since `seedIfEmpty()` only runs once.

## API surface

| Route | Notes |
|---|---|
| `GET /health` | |
| `GET /concepts/search?q=` | Matches concept names and aliases (e.g. "TAVR", "transcatheter" both resolve to the TAVR procedure). |
| `GET /concepts/category/{type}` | `type` = medication / procedure / condition / lab_value / equipment / protocol / anatomy |
| `GET /concepts/{id}` | Full concept detail incl. aliases + related concept ids |
| `POST /notes` | Persists a screened transcript. Does **not** trigger AI augmentation yet (see below). `createdAt` in the response is epoch millis, not an ISO string — deliberate, see below. |
| `GET /search-history`, `POST /search-history/{conceptId}`, `DELETE /search-history` | |
| `GET /suggestions` | Static list for now, not the real Suggestion Engine |
| `POST /chart-lookup` | Stateless — nothing persisted server-side. Matches `REQUIREMENTS.md`'s shift-scoped `LookupSession`, which lives client-local only. |

## Known scope limits (intentional, not oversights)

- **No AI pipeline.** `POST /notes` persists the note and stops — no LLM/embeddings calls, no concept extraction, no RAG. Needs a real Claude/embeddings API key and the async worker design from `SYSTEM_DESIGN.md`.
- **No `CorpusChunk`/pgvector usage yet.** The Postgres image (`pgvector/pgvector:pg16`) has the extension available, but nothing uses it — RAG is a later phase.
- **`Concept.sections` is a text column holding serialized JSON**, not a true `jsonb` column. Functionally fine for now; revisit if/when JSONB indexing or querying is actually needed.
- **Search is case-insensitive filtering in Kotlin, not SQL `ILIKE`/trigram.** Fine at this data scale; the trigram-index design in `SYSTEM_DESIGN.md` is the intended real implementation.
- **No auth.** Every route operates over one shared dataset — matches the still-open "solo personal use vs. multi-user" question in `REQUIREMENTS.md`.
- **No `ReviewSchedule`-driven suggestions.** `/suggestions` returns a static list; the real spaced-repetition ranking engine isn't built.
- **Timestamps are epoch millis (`Long`), not `Instant.toString()`.** The default Kotlin serialization emits a variable number of fractional-second digits (0, 3, 6, or 9), which broke naive `Codable` decoding on the iOS side — epoch millis sidesteps the whole format question. If anything reads these fields expecting an ISO string, that's now wrong; check `NoteDto`/`SearchHistoryDto` in `Models.kt`.

## Verified

Built and run inside Docker (`gradle:8.7-jdk21`) against the `docker-compose.yml` Postgres — every route above was hit with `curl` and returned correct responses, including alias-based search, chart-lookup with an unrecognized medication, search-history recording, and the full 28-concept seed set (category browse, cross-references via `relatedConceptIds`, acronym aliases like "DKA"/"PE"/"COPD"). Not yet run outside Docker / against a local JDK install.
