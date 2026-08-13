import Foundation

/// The phone's reply to a watch Ask-mode query (WatchConnectivityManager.ask
/// / WatchConnectivityReceiver on the phone side). Duplicated verbatim in
/// both targets rather than shared — there's no shared framework between the
/// watch and phone targets in this project, and the type is tiny.
struct AskResponse: Codable {
    let found: Bool
    let termName: String?
    let shortExplanation: String?
    let longExplanation: String?
}
