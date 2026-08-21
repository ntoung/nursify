import SwiftUI

@main
struct iosAppApp: App {
    // An app delegate owns AppState and activates Watch Connectivity at launch -
    // including background launches iOS makes to deliver a queued Watch clip -
    // so a note/question recorded on the watch is received and processed even
    // when the phone app was never opened. (Previously this only happened once
    // ContentView appeared, so a clip recorded with the app closed sat unhandled
    // and the watch stayed stuck on "sending".)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView(appState: appDelegate.appState)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    let appState = AppState()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Wire and activate the Watch Connectivity receiver up front (the
        // assignment forces the singleton to instantiate, which activates its
        // WCSession), so queued Watch clips are processed regardless of whether
        // the UI has appeared.
        WatchConnectivityReceiver.shared.appState = appState
        return true
    }
}
