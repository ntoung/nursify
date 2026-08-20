import SwiftUI

/// Watch settings page - currently just the app version/build, mirroring the
/// phone Home footer. A dedicated page so there's an obvious home for future
/// toggles, reachable by swiping past Capture and Ask.
struct WatchSettingsView: View {
    var body: some View {
        List {
            Section("About") {
                HStack {
                    Text("Version")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(AppInfo.version) (\(AppInfo.build))")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    WatchSettingsView()
}
