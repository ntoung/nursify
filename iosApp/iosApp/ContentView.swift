import SwiftUI

/// Root view: shows Onboarding until completed, then the 4-tab structure
/// (Capture, Search, Chart, Learn — ordered per mockups/v4, fast in-the-moment
/// tools first, reflective Learn last).
struct ContentView: View {
    @StateObject private var appState = AppState()

    var body: some View {
        Group {
            if appState.hasCompletedOnboarding {
                TabView {
                    CaptureView()
                        .tabItem { Label("Capture", systemImage: "mic.fill") }

                    SearchView()
                        .tabItem { Label("Search", systemImage: "magnifyingglass") }

                    ChartLookupInputView()
                        .tabItem { Label("Chart", systemImage: "list.bullet.clipboard") }

                    LearnView()
                        .tabItem { Label("Learn", systemImage: "point.3.connected.trianglepath.dotted") }
                }
                .tint(Theme.Color.accentInk)
            } else {
                OnboardingView()
            }
        }
        .environmentObject(appState)
        // On launch: refresh the offline concept library and replay any
        // mutations queued while offline. Both no-op silently when unreachable.
        .task {
            WatchConnectivityReceiver.shared.appState = appState
            await appState.flushOutbox()
            await appState.refreshLibrary()
        }
    }
}

#Preview {
    ContentView()
}
