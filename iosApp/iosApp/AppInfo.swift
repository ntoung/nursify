import Foundation

/// App marketing version + build number, read from the bundle Info.plist (both
/// set from `project.yml`). Shown in the Home footer here and mirrored in the
/// Watch app's settings page (WatchApp/AppInfo.swift).
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
