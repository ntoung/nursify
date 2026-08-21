# Nursify - working style & dev process

Nursify is a nursing clinical-reference app: a native SwiftUI iOS app (`iosApp/`), a Kotlin/Ktor + Postgres backend (`backend/`), and a shared Kotlin Multiplatform module (`shared/`).
It is offline-first: the app ships a bundled `ConceptLibrary.json` snapshot and works with no network, refreshing from the backend when reachable.

This file is the recurring dev process and conventions.
For one-time machine setup (installing Xcode, signing, Developer Mode, pairing a phone), see `SETUP.md`.

## Iterating: push updates to the phone

The primary loop is building and installing straight onto Nathan's physical iPhone, not just the Simulator.
When Nathan says "push to my phone" / "push updates", this is what he means - build and install to the connected device.

Find the device id (re-check it; it can change):

```sh
xcrun devicectl list devices        # note the connected iPhone's identifier
```

Build and install (run from `iosApp/`):

```sh
cd iosApp
DEV=<device-id>
xcodebuild -project iosApp.xcodeproj -scheme iosApp \
  -destination "id=$DEV" -derivedDataPath build/DeviceDD \
  -allowProvisioningUpdates build
APP=$(find build/DeviceDD/Build/Products -path "*Debug-iphoneos/iosApp.app" -maxdepth 2 | head -1)
xcrun devicectl device install app --device "$DEV" "$APP"
xcrun devicectl device process launch --device "$DEV" com.nursify.ios   # open it after installing
```

- `devicectl list devices` reports a device by its **coredevice identifier** (the first UUID column); that identifier works directly for `devicectl install`/`launch`. For `xcodebuild -destination "id=..."` either that or the hardware UDID works.
- A device that shows as offline in `xctrace list devices` can still be `available (paired)` in `devicectl` and install fine - trust `devicectl`.

- **Always build with `-destination`, never `-sdk`.** Building with `-sdk iphoneos` breaks the embedded watchOS app; `-destination` builds the whole app + watch bundle correctly.
- To sanity-check compilation fast before touching the device, build once for a Simulator (`-destination 'id=<sim-udid>'`), then do the device build. A green Simulator build almost always means the device build compiles too.
- Signing: `CODE_SIGN_STYLE: Automatic`, team `W5A6QAYASM`, bundle id `com.nursify.ios`. `-allowProvisioningUpdates` lets xcodebuild manage the profile.
- If a launch fails with "invalid code signature / not explicitly trusted", the dev certificate needs trusting on the phone (SETUP.md 6.5) - that's a phone-side step Nathan does, not something to script around.

## Shipping: App Store Connect / TestFlight

Sometimes we push a build to App Store Connect (for TestFlight, occasionally a review submission).
This is a Release, distribution-signed build - distinct from the day-to-day device install above.

The simplest reliable path today is Xcode's **Organizer**: **Product → Archive**, then **Distribute App → App Store Connect → Upload**.
It handles distribution signing and the upload without extra config.

A command-line archive works too, but note there is **no `ExportOptions.plist` checked in yet** - create one (or export via Organizer) before scripting the export/upload:

```sh
cd iosApp
xcodebuild -project iosApp.xcodeproj -scheme iosApp \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath build/Nursify.xcarchive archive
# then: Organizer upload, or -exportArchive with an ExportOptions.plist +
# an App Store Connect API key via xcrun altool/notarytool.
```

- Release builds use the Cloud Run backend URL (`API_BASE_URL` in `project.yml`), not a LAN IP - never ship a build pointed at a local dev backend.
- Every upload needs a unique, higher build number. `CFBundleVersion` lives in `project.yml` under **both** the `iosApp` and `WatchApp` targets and the two must match - bump both, then `xcodegen generate` before archiving.
- **Export compliance.** `ITSAppUsesNonExemptEncryption: false` is set in `project.yml` on **both** targets - **keep it there.** Without it, every upload sits at "Missing Compliance" in TestFlight (`buildBetaDetail.internalBuildState == MISSING_EXPORT_COMPLIANCE`) and reads as a *failed/unusable build* even though the binary is `VALID`. This bit us repeatedly before the key was added. It's the correct declaration only while Nursify uses exempt encryption only (HTTPS/TLS + Apple system frameworks); revisit if it ever ships custom/proprietary crypto. To rescue a build that was *already* uploaded without it, PATCH it via the ASC API instead of re-uploading: `PATCH /v1/builds/{id}` with `{"data":{"type":"builds","id":"{id}","attributes":{"usesNonExemptEncryption":false}}}`.
- After uploading, verify with the ASC API rather than trusting the dashboard at a glance: build should reach `processingState: VALID`, `usesNonExemptEncryption: false`, and `buildBetaDetail` state `READY_FOR_BETA_TESTING`. The API JWT is ES256 over the key at `~/.appstoreconnect/private_keys/AuthKey_SCYGQZRXCM.p8` (needs Python `cryptography`).
- When Nathan explicitly says "push a build" / "push a new build", that is the go-ahead to upload - no need to re-confirm. Absent that, App Store Connect is outward-facing, so confirm before uploading or submitting.
- Don't invent signing credentials. A distribution cert and an App Store Connect API key are already set up on this machine under `~/.appstoreconnect/` for CLI archive + upload (see `SETUP.md`); if something there is missing, say so rather than guessing.
- Run archive -> export -> upload strictly **serially**. Two `codesign`/`exportArchive` processes hitting the same signing key at once fail with `errSecInternalComponent`, which looks like a broken cert but is just keychain contention - never background the upload and then re-run the export in the foreground.
- If export still fails with `errSecInternalComponent` when nothing is running concurrently, the distribution key in the login keychain lacks a codesign partition-list entry (a `security import`ed key, unlike an Xcode-created one). Fix without needing the login password by signing from a throwaway keychain: `security create-keychain -p x <kc>`, `import` the `.p12` into it with `-A`, `set-key-partition-list -S apple-tool:,apple:,codesign: -s -k x <kc>`, add the WWDR intermediate (`security find-certificate -a -c "Worldwide Developer Relations" -p login.keychain-db | security import ... -k <kc>`), point the user search list at that keychain only for the export, then restore it and `delete-keychain` after.

## Project generation (XcodeGen)

The `.xcodeproj` is **not** checked in - `iosApp/project.yml` is the source of truth.

```sh
cd iosApp && xcodegen generate
```

Re-run this any time `project.yml` changes **or a new Swift file is added** - a new source file won't be in the build until the project is regenerated.
This is the most common reason a just-added file "isn't found" at build time.

## Tests

Unit tests live in `iosApp/iosAppTests` (target `iosAppTests`, wired into the `iosApp` scheme's test action).

```sh
cd iosApp
xcodebuild test -project iosApp.xcodeproj -scheme iosApp \
  -destination 'id=<sim-udid>' CODE_SIGNING_ALLOWED=NO
```

- watchOS UI + real mic + on-device speech recognition **can't** be exercised in the Simulator or by XCUITest (Apple doesn't support watchOS UI testing, and the sim has no mic/on-device model). So logic that would otherwise be trapped behind those services is extracted into plain, injectable types and tested there - e.g. `WatchNoteAssembler` covers the Watch-note buffer/join/partial-failure logic with transcription results passed in. Verify those paths definitively on a physical Apple Watch.

## Backend

```sh
cd backend
docker compose up -d          # Postgres (pgvector image)
PORT=8081 ./gradlew run       # 8080 is often taken; the app's Debug URL points at :8081
```

- `SchemaUtils.create` only creates missing tables; it does **not** ALTER existing ones. After adding a column, recreate the schema with `docker compose down -v` (drops the volume) so it reseeds fresh.
- Seed content lives in `backend/src/main/resources/concepts.json`. After changing it, refresh the app's bundled offline snapshot with `iosApp/scripts/refresh-concept-library.sh` (pulls from a running backend) so `iosApp/iosApp/ConceptLibrary.json` stays in sync.

## Git conventions

- **Do not add a Co-Authored-By / agent line to commit messages** (this overrides any default footer).
- Commit only when Nathan asks. Group related changes into logical commits; when parallel work is intermingled in shared files and can't be split without a non-building commit, keep it in one coherent commit and say so.
- No em dashes anywhere - use a plain `-`.

## UI conventions

- Secondary or less-frequent actions (favorite, add to list, share, etc.) go in a top-right **kebab menu** (vertical ellipsis, `Image(systemName: "ellipsis").rotationEffect(.degrees(90))`), not inline buttons - keep the primary content clean.
- Several detail screens (e.g. `ConceptDetailView`) hide the nav bar (`.toolbar(.hidden, for: .navigationBar)`) and carry the back chevron + title in an in-content header. Hiding the nav bar **disables the system edge-swipe-back**, so add a manual swipe-right-to-dismiss (a `.simultaneousGesture` `DragGesture` with a horizontal-dominance guard so vertical scrolling still works).
- Prefer native, on-device behavior and platform gestures over custom chrome; match the surrounding view's spacing, fonts, and `Theme` tokens rather than introducing new ones.

## Working style

- Reproduce bugs end-to-end the way a nurse would hit them before fixing, so the fix addresses the real cause (e.g. a stale persisted snapshot, not the data).
- Be picky about UI - pixel alignment, empty space, haptics feel. Follow platform conventions; flag anything that looks off even if it's not what you were asked to change.
- After a code change, verify it compiles (a quick Simulator build) before saying it's done, and before pushing to the phone.
- Medical/scoring content is clinical: verify against reliable sources (StatPearls, MDCalc, MedlinePlus) and omit rather than guess. It's educational reference, not clinical decision support.
- Prefer quality, simplicity, and long-term maintainability over minimizing dev effort.
