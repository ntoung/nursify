# iosApp

Native SwiftUI iOS app (primary UI target). Scaffolded on Windows, so no `.xcodeproj` is checked in — generate it on macOS with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

Setting up a Mac from scratch (Xcode, signing, running on a physical device)? See [`SETUP.md`](../SETUP.md) at the repo root for the full walkthrough.

```sh
brew install xcodegen
cd iosApp
xcodegen generate
open iosApp.xcodeproj
```

`project.yml` is the source of truth for the Xcode project (targets, bundle id, deployment target). Regenerate after changing it or adding new source files/groups.

## Networking: direct to `backend/`, not through `shared/`

The app talks to `../backend` over plain HTTP (`APIClient.swift`, `URLSession` + `Codable`) — **not** through the `shared` Kotlin Multiplatform module, even though `shared/ApiClient.kt` implements the same surface. Reason: actually consuming `shared` means building it as an `.xcframework` in Xcode, which needs macOS and can't be done or verified from here. Direct native networking is real today; `shared` remains the documented future consolidation path once someone's on a Mac to do that integration and can delete this duplication.

`APIClient.shared` defaults to `http://localhost:8080` — correct for the Simulator talking to a backend running on the same Mac (iOS's ATS loopback exception covers this, no `Info.plist` changes needed). A real device needs the Mac's LAN IP instead.

**None of this has been compiled** — no Xcode/Simulator available in this environment. Wire format was cross-checked field-by-field against live `curl` responses from a running backend (see `backend/README.md`), and one real bug was caught that way (`MedicationExplanation` was missing a `found` field and required an `id` the backend never sends — fixed with a custom `Codable` implementation in `Models.swift`). Brace/paren balance was checked by hand across every file. Still: **build this on a Mac before trusting it further.**

## Layout

```
iosApp/
  project.yml            # XcodeGen project spec
  iosApp/
    iosAppApp.swift       # @main entry point
    ContentView.swift     # onboarding gate + 4-tab root (Capture/Search/Chart/Learn)
    AppState.swift        # ObservableObject — owns network calls, drives all views
    APIClient.swift        # URLSession-based backend client
    Models.swift           # data models; wire-format-compatible with backend/shared
    MockData.swift          # demo seed data — still used for Capture's initial
                             # note list and Chart Lookup's initial history
                             # (both are local-only / no GET endpoint to fetch from)
    Components.swift        # ConceptCard (tap-to-expand), chips, badges, etc.
    Theme.swift              # colors/fonts/FlowLayout — ported from mockups/v4
    OnboardingView.swift
    SearchView.swift         # search + category browse + recent/history (networked)
    LearnView.swift          # suggestion feed (networked)
    CaptureView.swift        # notes list (local) + typed note capture (networked)
    ConceptDetailView.swift  # fetches by id (networked)
    ChartLookupView.swift    # input (networked) + history (local) + results
```

## What's networked vs. still local

| Feature | Backed by |
|---|---|
| Search, category browse, concept detail | `backend/` — live |
| Suggestions | `backend/` — live, but the endpoint itself just returns a static list (no real Suggestion Engine yet) |
| Search history (Learn page) | `backend/` — live, synced |
| Chart Lookup explanations | `backend/` — live, stateless |
| Chart Lookup **history** | Local only, by design — `LookupSession` never touches the backend (see `REQUIREMENTS.md` — no PHI ever leaves the device) |
| Capture note list | Local only — there's no `GET /notes` endpoint yet. New notes typed in the app do `POST` to the backend and get appended locally; nothing re-fetches the list. |
| Voice recording / transcription / PHI screening | **Not implemented at all.** Capture's "record" button opens a plain text field instead — see the comment in `CaptureView.swift`. |

## Known gaps / follow-ups

- **N+1 requests on concept detail.** Each "related concept" chip fetches its own name via a separate request just to render a label — fine at this data scale, worth a batch endpoint later.
- **No offline handling.** If the backend is unreachable, views show an inline error/retry rather than falling back to cached data — `shared/`'s `ConceptCache` design exists for exactly this but isn't wired in yet.
- **No auth** — matches the backend's current no-auth state.
