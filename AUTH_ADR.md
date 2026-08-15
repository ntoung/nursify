# ADR: Accounts, Auth, and Hospital/Org Modeling

Companion to `REQUIREMENTS.md` and `SYSTEM_DESIGN.md`. This is the
prerequisite work that any hospital-facing feature (rollup reporting,
team-readiness views, admin dashboards) depends on. Split out from
`GAMIFICATION_ADR.md` deliberately — it's a real, separate project, not a
detail of the badges/metrics feature.

Status: proposed — deferred. Not being built now. This document exists to
name the problem and its shape so it's decided deliberately later, rather
than backed into incrementally.

## Context

`REQUIREMENTS.md` already lists "solo personal use vs. multi-user" as an
open question. Today, that question is answered by default, not by design:
there is no user identity anywhere server-side. `Routing.kt` operates over
one shared dataset for every request. `AppState`'s `UserProfile` (name,
specialties, experience) is device-local `UserDefaults`, never synced to a
server-side profile, because there's no server-side profile to sync to.

Any feature where a hospital or unit views something about "its nurses" —
even in aggregate — requires knowing what a nurse, a hospital, and the
relationship between them *is* in the data model, and requires an actual
authentication mechanism so that identity can't be spoofed or guessed. That's
this ADR's scope.

`GAMIFICATION_ADR.md` was deliberately designed to not depend on this: its
badges/metrics stay entirely on-device, specifically so that work could
proceed without this decision being made first.

## Decision axes (not yet decided)

These need real answers before any implementation, each with meaningfully
different cost and UX implications:

- **Identity provider.** Roll-your-own email/password, Sign in with Apple
  (fits an iOS-first app well), or a managed auth provider (e.g. an
  Auth0/Clerk-style service) if/when hospital SSO (SAML/OIDC via the
  hospital's own IdP) becomes a real requirement — likely, given the
  enterprise buyer, but not needed for a v1.
- **Org modeling.** What is a "hospital" or "unit" as a data entity — does
  a nurse belong to exactly one, can they belong to none (personal use
  continues to exist), how does a nurse get associated with one (self-serve
  join code, admin invite, email-domain matching)?
- **Roles.** At minimum: nurse (own data only) vs. some kind of unit
  admin/manager (aggregate view only, per `GAMIFICATION_ADR.md`'s
  aggregate-only constraint — never raw per-nurse activity).
- **Consent.** Whether joining an org auto-shares aggregate stats, or is a
  separate opt-in — this is a product and likely legal decision, not just an
  engineering one, given the employee-monitoring adjacency.
- **Session/token strategy across iOS + watchOS.** The watch app currently
  talks to the phone (WatchConnectivity) and the phone talks to the backend;
  auth needs to fit that shape, not assume a device that can independently
  hold a session.
- **Migration path.** Today's backend data (notes, search history) has no
  owner. Retrofitting ownership onto existing rows, vs. treating this as a
  clean cutover, is itself a decision with real data-loss/UX tradeoffs.

## Deliberately out of scope until this is prioritized

- Any backend schema changes for users/orgs/roles.
- Any hospital-facing dashboard or rollup view (that's a further ADR, gated
  on this one).
- Any change to `GAMIFICATION_ADR.md`'s local-only design — it doesn't need
  to change when this eventually gets decided; a future sync layer would be
  additive on top of it, not a rework of it.

## Why this is its own ADR

Auth and multi-tenancy decisions are expensive to reverse once real user data
exists under them, and they carry legal/consent weight this codebase hasn't
had to reason about yet (this is the first feature area where "what does a
nurse's employer get to see" is a live question). Bundling that decision
into a gamification feature would mean either rushing it or blocking
gamification on it — both worse than deciding it deliberately, on its own
timeline, when hospital-facing reporting is actually being prioritized.
