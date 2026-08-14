import SwiftUI

/// Root view: shows Onboarding until completed, then the 4-tab structure
/// (Capture, Search, Charts, Learn — ordered per mockups/v4, fast in-the-moment
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

                    ChartsListView()
                        .tabItem { Label("Charts", systemImage: "list.bullet.clipboard") }

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
        // mutations queued while offline (both no-op silently when
        // unreachable), and prime speech-recognition permission so a Watch
        // recording finished before ever dictating on the phone still
        // transcribes — see SpeechCapture.requestSpeechPermissionIfNeeded.
        .task {
            WatchConnectivityReceiver.shared.appState = appState
            await appState.flushOutbox()
            await appState.refreshLibrary()
            await SpeechCapture.requestSpeechPermissionIfNeeded()
        }
    }
}

#Preview {
    ContentView()
}
