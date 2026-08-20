import Foundation

/// App marketing version + build number, read from the Watch bundle's
/// Info.plist (set from `project.yml`). Mirrors the phone app's AppInfo so the
/// Watch settings page shows the same version/build the phone Home footer does.
enum AppInfo {
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
    }

    /// e.g. "Version 1.0 (9)".
    static var versionLabel: String { "Version \(version) (\(build))" }
}
