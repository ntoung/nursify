import Foundation

/// The phone's reply to a watch Ask-mode query (WatchConnectivityReceiver
/// here / WatchConnectivityManager.ask on the watch side). Duplicated
/// verbatim in both targets rather than shared — there's no shared framework
/// between the watch and phone targets in this project, and the type is tiny.
struct AskResponse: Codable {
    let found: Bool
    let termName: String?
    let shortExplanation: String?
    let longExplanation: String?
    /// Set only on a genuine failure to hear/transcribe the query (denied
    /// permission, no on-device model, silence) — distinct from `found ==
    /// false` with this nil, which means transcription worked fine but no
    /// concept matched. Without this, both cases showed the same "couldn't
    /// find a match" message, which is actively misleading when the real
    /// problem is that nothing was heard at all.
    let errorMessage: String?
}
