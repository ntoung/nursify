# Mac setup: building and running Nursify

This is a from-scratch guide for getting a Mac ready to build the iOS app and run it against a local backend, either in the Simulator or on a physical iPhone.
It assumes a clean machine with nothing but Command Line Tools installed.

## 1. Install Xcode

The full Xcode.app is required.
Command Line Tools alone are not enough - `xcodebuild`, the Simulator, and on-device deployment all need it.

1. Open the App Store and sign in with your Apple ID.
2. Search for "Xcode" and install it (roughly 2-3 GB to download, more once unpacked).
3. Once installed, point the system at it and accept the license:
   ```sh
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   sudo xcodebuild -license accept
   ```
   Both commands need your password interactively, so run them in a real terminal, not through an automated script.
4. Verify:
   ```sh
   xcodebuild -version
   ```

## 2. Install XcodeGen

The Xcode project isn't checked in.
`iosApp/project.yml` is the source of truth and XcodeGen turns it into `iosApp.xcodeproj`.

```sh
brew install xcodegen
cd iosApp
xcodegen generate
```

Re-run `xcodegen generate` any time `project.yml` changes (new source files, new Info.plist keys, signing settings, and so on).

## 3. Start the backend

The app talks to `backend/` over plain HTTP.
Requires Docker.

```sh
cd backend
docker compose up -d      # starts Postgres
./gradlew run              # starts the Ktor server on :8080
```

If `./gradlew` fails with a "Permission denied" or "bad interpreter" error, the executable bit was lost (this repo was originally scaffolded on Windows).
Fix it once with `chmod +x gradlew`.

If port 8080 is already taken by something else on your Mac, run on a different port instead:

```sh
PORT=8081 ./gradlew run
```

If you run the backend without a local JDK, use the Docker-based approach instead (see `backend/README.md` for the exact `docker run` invocation against `gradle:8.7-jdk21`).

Confirm it's up:

```sh
curl http://localhost:8080/health   # -> ok
```

## 4. Point the app at your backend

`iosApp/iosApp/APIClient.swift` hardcodes the backend's base URL.

- **Simulator only:** `http://localhost:8080` works as-is (iOS's ATS loopback exception covers this).
- **Physical device:** the phone can't reach your Mac's `localhost`, so use your Mac's LAN IP instead:
  ```sh
  ipconfig getifaddr en0
  ```
  Update the `baseURL` in `APIClient.swift` to `http://<that-ip>:<port>`.

This IP changes if your Mac reconnects to Wi-Fi or its DHCP lease renews - if the app suddenly can't reach the backend, this is the first thing to check.

`project.yml` already carries the matching ATS exception (`NSAllowsLocalNetworking: true`) needed to allow plain HTTP to a LAN address, so no further Info.plist changes are needed after switching the IP.

## 5. Run in the Simulator

The simplest path, and a good sanity check before dealing with a physical device:

```sh
cd iosApp
open iosApp.xcodeproj
```

Pick any iPhone simulator as the run destination and hit **Run** (⌘R).

If no simulators are listed, download the iOS platform:

```sh
xcodebuild -downloadPlatform iOS
```

## 6. Run on a physical iPhone

A few one-time steps are needed beyond the Simulator setup above.

### 6.1 Sign in with your Apple ID

In Xcode: **Settings → Accounts → +** and sign in.
This is what lets Xcode generate a free development signing certificate.

### 6.2 Select a signing team

`project.yml` sets `CODE_SIGN_STYLE: Automatic`, so a team just needs to be chosen once:

1. Select the **iosApp** project in the navigator (blue icon).
2. Select the **iosApp** target under **TARGETS** (not the project itself - that's a common miss, since only the target has a Signing & Capabilities tab).
3. Under **Signing & Capabilities**, choose your Apple ID under **Team**.

### 6.3 Enable Developer Mode on the iPhone

**Settings → Privacy & Security → Developer Mode** → toggle on.
The phone will restart and ask for confirmation once it's back up.

### 6.4 Connect and trust the device

Plug the iPhone in via USB (or use the same Wi-Fi network for wireless debugging).
When prompted on the phone, tap **Trust This Computer** and enter the passcode.

In Xcode's **Window → Devices and Simulators**, the phone should show up and finish pairing.
If it's stuck on "unpaired" after trusting, re-select the device there and let it re-pair.

### 6.5 Trust the developer certificate on the phone

The first time you install a freely-signed app, iOS refuses to launch it until you explicitly trust the certificate:

**Settings → General → VPN & Device Management** → tap the developer profile (your Apple ID) → **Trust**.

### 6.6 Run it

With the iPhone selected as the destination in Xcode, hit **Run** (⌘R).

## Command-line equivalent

Everything above can also be done without opening Xcode's GUI, useful for scripting or CI-style runs.
Find your device and its identifier:

```sh
xcrun devicectl list devices
```

Build, install, and launch:

```sh
cd iosApp
xcodebuild -project iosApp.xcodeproj -scheme iosApp \
  -destination 'id=<device-id>' -allowProvisioningUpdates install

xcrun devicectl device install app --device <device-id> \
  "$(xcodebuild -project iosApp.xcodeproj -scheme iosApp -showBuildSettings 2>/dev/null | awk -F' = ' '/CODESIGNING_FOLDER_PATH/ {print $2; exit}')"

xcrun devicectl device process launch --device <device-id> com.nursify.ios
```

## Troubleshooting

**"iOS 26.x is not installed"** when building for a device - download on-device debug symbols:
```sh
xcodebuild -prepareDeviceSupport -platform iOS -osVersion <version> -modelCode <model>
```
(`xcrun devicectl list devices` shows the model code, e.g. `iPhone17,2`.)

**Destinations stuck showing stale pairing/Developer Mode errors** even after fixing the underlying issue - restart Xcode and the CoreSimulator/CoreDevice background services:
```sh
killall -9 com.apple.CoreSimulator.CoreSimulatorService
```
then reopen Xcode.

**"Unable to launch ... invalid code signature ... not been explicitly trusted"** - you skipped step 6.5 above (trusting the developer certificate on the phone itself).
