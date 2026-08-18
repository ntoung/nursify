import SwiftUI

/// Root view: shows Onboarding until completed, then the 3-tab structure
/// (Home, Journal, Search — Home stays leftmost for the tab-bar order, but
/// Journal is where a nurse actually wants to land: see `selectedTab`).
/// Journal replaces what used to be separate Capture/Charts tabs — see
/// JournalView.
struct ContentView: View {
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase
    private enum Tab: Hashable { case home, journal, search }
    @State private var selectedTab: Tab = .journal
    @State private var isReportingProblem = false

    var body: some View {
        Group {
            if appState.hasCompletedOnboarding {
                TabView(selection: $selectedTab) {
                    HomeView()
                        .tabItem { Label("Home", systemImage: "point.3.connected.trianglepath.dotted") }
                        .tag(Tab.home)

                    JournalView()
                        .tabItem { Label("Journal", systemImage: "book.closed") }
                        .tag(Tab.journal)

                    SearchView()
                        .tabItem { Label("Search", systemImage: "magnifyingglass") }
                        .tag(Tab.search)
                }
                .tint(Theme.Color.accentInk)
            } else {
                OnboardingView()
            }
        }
        .environmentObject(appState)
        .gamificationUnlockDialog(appState.gamification)
        // Instagram-style shake-to-report: a shake anywhere opens the
        // "Report a problem" drawer.
        .onShake { isReportingProblem = true }
        .sheet(isPresented: $isReportingProblem) {
            ReportProblemView()
        }
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
        // on iOS, not a real foreground/background boundary), and only once
        // onboarding is complete — First Shift and its unlock dialog should
        // show after the nurse taps Get Started, not mid-onboarding.
        // completeOnboarding() logs the first one directly (see AppState).
        .onChange(of: scenePhase) { oldPhase, newPhase in
            guard appState.hasCompletedOnboarding else { return }
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
