# iosApp

Native SwiftUI iOS app (primary UI target). Scaffolded on Windows, so no `.xcodeproj` is checked in — generate it on macOS with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
brew install xcodegen
cd iosApp
xcodegen generate
open iosApp.xcodeproj
```

`project.yml` is the source of truth for the Xcode project (targets, bundle id, deployment target). Regenerate after changing it or adding new source files/groups.

## Layout

```
iosApp/
  project.yml          # XcodeGen project spec
  iosApp/
    iosAppApp.swift     # @main app entry point
    ContentView.swift   # root view (tab scaffold: Capture / Learn / Chart)
    Assets.xcassets/    # app icon, accent color
```

## Status

UI scaffold only — placeholder tabs for Capture, Learning Graph, and Chart Lookup. No shared Kotlin Multiplatform module wired up yet; that's next (see `REQUIREMENTS.md` roadmap).
