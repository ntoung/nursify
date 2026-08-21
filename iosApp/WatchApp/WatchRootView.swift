import SwiftUI

/// Two swipeable pages: the single Capture entry point (record a note, or ask
/// "what is..." - the phone decides which) and Settings. There's no separate
/// "note" vs. "term" page anymore; the nurse just talks and the phone routes it.
struct WatchRootView: View {
    var body: some View {
        TabView {
            WatchCaptureView()
            WatchSettingsView()
        }
        .tabViewStyle(.page)
        // Activate Watch Connectivity at launch (not only on the first
        // recording) so a result the phone already sent is received right away,
        // updating any row still showing "sending…".
        .task { _ = WatchConnectivityManager.shared }
    }
}

#Preview {
    WatchRootView()
}
