import SwiftUI

/// Root view: shows Onboarding until completed, then the 4-tab structure
/// (Capture, Search, Charts, Home — ordered per mockups/v4, fast in-the-moment
/// tools first, reflective Home last).
struct ContentView: View {
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

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

                    HomeView()
                        .tabItem { Label("Home", systemImage: "point.3.connected.trianglepath.dotted") }
                }
                .tint(Theme.Color.accentInk)
            } else {
                OnboardingView()
            }
        }
        .environmentObject(appState)
        .gamificationUnlockDialog(appState.gamification)
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
        // Foreground/background transitions drive the "hours of active
        // usage" metric and the First Shift / daily-points signal — see
        // GAMIFICATION_ADR.md. Only fires on real transitions, not every
        // scenePhase change (`.inactive` is a transient mid-transition state
        // on iOS, not a real foreground/background boundary).
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active, oldPhase != .active {
                appState.gamification.logAppForegrounded()
            } else if oldPhase == .active, newPhase != .active {
                appState.gamification.logAppBackgrounded()
            }
        }
    }
}

#Preview {
    ContentView()
}
