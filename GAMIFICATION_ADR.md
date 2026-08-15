# ADR: Gamification and Personal Metrics

Companion to `REQUIREMENTS.md` and `SYSTEM_DESIGN.md`. Scope: badges, usage
metrics, and periodic (week/month/year) summaries for the individual nurse,
entirely on-device. No implementation yet; this is the design pass, to be
reviewed before any code is written.

Hospital-facing reporting and the accounts/auth system it depends on are
**explicitly out of scope here** — see "Deliberately out of scope" below.
They get their own ADRs (`AUTH_ADR.md` and, later, a hospital-rollup ADR that
depends on it).

Status: proposed.

## Context

The codebase has no user identity anywhere server-side — `Routing.kt` states
outright that every route operates over one shared dataset, and
`REQUIREMENTS.md` already lists "solo personal use vs. multi-user" as an
open, unresolved question. That's the reason this feature is scoped to the
device: there's currently nothing to attach server-side per-nurse state to,
and standing that up is a separate, weighty decision (see `AUTH_ADR.md`), not
something to back into as a side effect of badges.

There's also a live precedent worth carrying forward even though it's not
directly triggered yet: the ICU/charge-nurse panel asked for chart-lookup
activity to surface only as an aggregate, patient-delinked count, never raw
detail. Chart Lookup itself never reaches the backend today, by design.
Nothing in this feature should create a new path that quietly routes around
that boundary.

`LearnView` today is close to a placeholder — a greeting plus an honest
"nothing to review yet" empty state, because the real Suggestion Engine isn't
built. That makes it the natural home for this feature: it fills a page
that's currently mostly empty, rather than competing with existing content.

## Decision

Build gamification and metrics now, entirely on-device (SwiftData), with no
backend changes — while validating the shape of the data locally before ever
considering whether it's worth syncing anywhere. Concretely:

- One local, append-only event log is the source of truth. Badges, counters,
  and summaries are all queries over it, not separately maintained counters.
- Rename the "Learn" tab to **Home**. It hosts the badge shelf, the periodic
  usage summary, and (cheap-version) learning tidbits.
- A badge unlocking shows as a transient dialog with a badge graphic,
  wherever the nurse currently is in the app.

## Data model (conceptual)

Event types logged locally:

- `ConceptViewed(conceptId, conceptType, source, at)` — logged at every real
  concept-detail open (search result tap, Home suggestion tap, related-concept
  chip, note-mention tap, chart-lookup medication expand). Extends the
  existing `recordSearchHistory` call site rather than duplicating it.
- `SearchPerformed(normalizedQuery, resultCount, at)` — total vs. distinct
  search counts. The query text itself never needs to leave this local store
  for this feature to work — worth keeping in mind if this ever gets
  reconsidered for sync later, but not a live constraint while everything's
  local.
- `NoteCaptured(device, mentionedConceptCount, at)`.
- `ChartLookupSessionCompleted(medicationCount, complaintCount, at)` — see
  "patients" resolution below.
- `AppForegrounded` / `AppBackgrounded` (via `scenePhase`) — foreground time
  as active-usage minutes/hours. Simplest honest measure for a tool used in
  short, frequent bursts; no idle-detection needed.

Store via SwiftData (native to the iOS 17+ target already in use, typed
queries, no new dependency). This is a separate local store from the
existing offline-sync/outbox machinery — it's not meant to sync, so it
doesn't need that machinery.

One aggregation layer sits on top of the event log and powers both the badge
shelf and the usage summary — same queries (distinct concepts by type,
counts by date range), two presentations, so they can't drift out of sync
with each other.

### "Patients" badge — resolved

Confirmed: this counts Chart Lookup sessions, not conditions or any other
proxy. A completed chart-lookup session (the nurse got explanations back) is
close enough to a real encounter, and it's already patient-delinked by
construction — nothing new needed to keep it that way.

### Usage summary (week / month / year)

A lightweight rollup view, separate from the badge shelf, showing counts over
a selectable period: concepts viewed (by type), searches performed, notes
captured, chart-lookup sessions, active-usage time. Same date-ranged queries
over the same event log — this is presentation, not a second data model.

### Badges

Declarative rules over aggregates, kept as a static Swift list for now
(matches the Suggestion Engine's own "static for now" precedent — no need
for a server-driven catalog until there's a reason to ship new badges without
an app update). Tiered where it makes sense so a badge is a milestone ladder,
not one-and-done.

| Badge | Signal |
|---|---|
| First Shift | opening the app for the very first time |
| Book Worm (Bronze/Silver/Gold) | distinct concepts viewed, any type |
| Pharmacist in Training | distinct medications viewed |
| Procedure Pro | distinct procedures viewed |
| Detective | distinct conditions viewed |
| Lab Rat | distinct lab values viewed |
| By the Book | distinct protocols/order sets viewed |
| Full Coverage | at least one concept viewed from every type |
| Specialist | % of concepts tagged to the nurse's specialty viewed |
| Note Taker | notes captured |
| Making Rounds | chart-lookup sessions completed |

Streak-based badges are explicitly deferred — not designed here.

`First Shift` unlocks on the very first `AppForegrounded` event ever logged
(no new event type needed — "first session" is just the absence of any prior
one). It's deliberately the easiest badge in the system and fires
immediately post-onboarding: its entire job is to teach a first-time nurse
that the badge system exists at all, by showing them the unlock dialog
before they've done anything else.

### Badge graphics

Each badge gets a circular medallion — a colored background disc behind a
large SF Symbol, reusing the exact visual language `OnboardingView`'s
welcome page already established (`Circle().fill(accentSoftBackground)` +
a bold-weight `Image(systemName:)`), just with a badge-specific icon and
accent color instead of the app's single default. E.g. `book.fill` for Book
Worm, `pills.fill` for Pharmacist in Training, `stethoscope` for Procedure
Pro, `magnifyingglass` for Detective, `flask.fill` for Lab Rat,
`list.clipboard.fill` for By the Book, `checkmark.seal.fill` for Full
Coverage, `star.fill` for Specialist, `pencil.and.list.clipboard` for Note
Taker, `figure.walk` for Making Rounds, `hand.wave.fill` for First Shift.

This is the pragmatic v1 choice, not a compromise dressed up as one: it's
zero new asset pipeline, zero bundle-size growth, and it's consistent with
an app that's SF-Symbols-only everywhere else today. Given this whole phase
is explicitly about validating the badge set locally before investing
further, committing to commissioned illustrated artwork for a taxonomy that
might still change is the wrong order of operations. Once the badge set
settles, swapping in real illustrated art later is a pure visual upgrade —
nothing about the data model or unlock logic would need to change.

### Points & levels

Points and levels are a second presentation over the same event log and
badge state — not a new thing to track, and not user-facing at the
per-action level.

**Points are a derived aggregate, computed on demand from the event log —
there is no separate "points" event and no running counter written
anywhere.** Same pattern as badge progress and the usage summary: one
source of truth, a pure function on top.

Per-event point values (small, so routine use trickles rather than spikes):

| Event | Points |
|---|---|
| `ConceptViewed` | 2 |
| `SearchPerformed` | 1 |
| `NoteCaptured` | 5 |
| `ChartLookupSessionCompleted` | 5 |
| `AppForegrounded`, first time that calendar day | 3 |

`AppForegrounded` only pays out once per day, not once per foreground —
otherwise backgrounding and reopening the app repeatedly would be a trivial
way to farm points for nothing. Every other event pays out every time it
happens, since each represents a real, bounded action.

Badge-unlock bonus, much larger than any single action — badges are
milestones and should feel like one:

| Badge tier | Bonus |
|---|---|
| `First Shift` | 20 |
| Single-tier badge (Pharmacist in Training, Procedure Pro, Detective, Lab Rat, By the Book, Full Coverage, Specialist, Note Taker, Making Rounds) | 50 |
| Tiered badge — Bronze | 30 |
| Tiered badge — Silver | 75 |
| Tiered badge — Gold | 150 |

Level is a closed-form curve over total points, so it's cheap to compute and
cheap to retune later — `threshold(level) = 50 × level × (level − 1)`:

| Level | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|---|
| Points needed | 0 | 100 | 300 | 600 | 1,000 | 1,500 | 2,100 |

In practice: `First Shift` alone (20) plus a first session of ordinary
browsing gets a new nurse close to Level 2 within their first sitting;
Level 3+ takes sustained use over days/weeks, which is the intent — early
levels reward just trying the app, later ones reward actually building it
into a habit. All of these numbers are constants in one place, not
architecture — expect to retune once there's real usage data.

**UI treatment**, matching "don't show +5 points when clicking on insulin":
the running point total is never surfaced as per-action feedback — no
toasts, no incrementing counter live on screen. The current **Level** is
shown as a standing indicator on Home (name/number plus a light progress bar
toward the next one) — that's the one persistent, ambient signal. Leveling
up gets the same transient unlock-dialog treatment as a badge, since it's a
milestone in the same spirit and can show the point bump that triggered it
as part of that specific celebration — crossing it silently would undercut
the reason levels exist. This dialog-content point is a recommendation, not
something explicitly asked for — flagging it in case a quieter treatment is
preferred.

### Learning tidbits — cheap version now

The real version is spaced-repetition resurfacing via a real Suggestion
Engine, which means reviving the currently-unused `ReviewSchedules` table —
a real feature in its own right, already scoped in `REQUIREMENTS.md`, and out
of scope here.

Cheap version, buildable now with what exists: a card on Home surfacing one
not-yet-viewed concept matching the nurse's chosen specialty. Reuses
`UserProfile.specialties` and the existing concept corpus. Explicitly a
placeholder for the real thing, not a competing implementation of it.

## IA changes

- `LearnView.swift` → renamed to reflect the Home tab (greeting stays; the
  current empty state is replaced by real content: level indicator, badge
  shelf, usage summary, learning-tidbit card).
- Unlock dialog: a transient, modal overlay (badge graphic + name + short
  description, or a "Level up!" variant) that can appear over any tab (the
  nurse might unlock "Pharmacist in Training" while on Search, not while on
  Home) — an app-level concern similar to how `captureError`/`errorMessage`
  are already surfaced today, not a per-screen one. Covers badge unlocks and
  level-ups; never fires for a plain point gain.

## Deliberately out of scope

- **Hospital-facing rollups.** Real future work, not hypothetical, but it's
  a separate task with its own ADR, gated on the item below.
- **Accounts / auth / hospital-org modeling.** Split into `AUTH_ADR.md` as
  its own decision, since it's a real project (identity, sessions, roles,
  migration of today's single shared dataset) that shouldn't ride in on a
  gamification feature. This ADR's local-only design means nothing here
  blocks or depends on how that gets resolved.
- **Streaks.** Deferred per direction above — not designed, not stubbed.

## Alternatives considered

- **Sync raw per-item events to the backend now, keyed by a device ID (no
  real accounts).** Rejected — a persistent device ID correlated
  server-side is a user identity in everything but name, without any of the
  consent/auth scaffolding a real one would get.
- **Design the hospital rollup and auth model in this same ADR.** Rejected
  per explicit direction — split out to keep this scoped to what's actually
  being built now.

## Consequences

- Ships as an iOS-only feature — no backend or schema changes.
- Every badge/metric is explainable to a nurse as "just for you, stays on
  your phone," which validates the data shape honestly before any future
  decision about whether/how to share it.
- Because it's local-only, the schema can be iterated on freely (SwiftData
  migrations are cheap at this stage) without any coordination cost with the
  backend — deliberate, since the goal right now is validating the model,
  not locking it in.
