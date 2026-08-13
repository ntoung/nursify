import Foundation
import WatchConnectivity

/// Hands recorded clips to the phone via Watch Connectivity's durable
/// transfer queues. Both `transferFile` and `transferUserInfo` persist and
/// retry across relaunches and out-of-range gaps, unlike `sendMessage` which
/// needs an active connection — matching REQUIREMENTS.md's "queued" capture
/// model.
///
/// A note built from multiple watch recordings (WatchNoteDraft) sends each
/// clip as its own file tagged with a shared `sessionId` + `sequence`, then
/// a final `transferUserInfo` "session complete" marker carrying the total
/// clip count once the nurse taps Done. The phone (WatchConnectivityReceiver)
/// buffers clips per session and only surfaces a note for review once it has
/// every clip the completion marker says to expect — see that file for why.
@MainActor
final class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()

    @Published private(set) var pendingTransferCount = 0

    private let session: WCSession? = WCSession.isSupported() ? .default : nil

    override init() {
        super.init()
        session?.delegate = self
        session?.activate()
    }

    @discardableResult
    func send(fileAt url: URL, sessionId: UUID, sequence: Int) -> WCSessionFileTransfer? {
        guard let session else { return nil }
        let metadata: [String: Any] = ["sessionId": sessionId.uuidString, "sequence": sequence]
        let transfer = session.transferFile(url, metadata: metadata)
        refreshPendingCount()
        return transfer
    }

    /// Tells the phone how many clips to expect for `sessionId` so it knows
    /// when the note is complete rather than guessing from file arrivals
    /// alone (file and userInfo transfers are independent queues with no
    /// ordering guarantee between them).
    func finishSession(id: UUID, clipCount: Int) {
        session?.transferUserInfo([
            "type": "sessionComplete",
            "sessionId": id.uuidString,
            "totalCount": clipCount
        ])
    }

    private func refreshPendingCount() {
        pendingTransferCount = session?.outstandingFileTransfers.count ?? 0
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in WatchConnectivityManager.shared.refreshPendingCount() }
    }

    nonisolated func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        Task { @MainActor in WatchConnectivityManager.shared.refreshPendingCount() }
    }
}
