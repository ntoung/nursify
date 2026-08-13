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
///
/// Ask mode (a single spoken term, answered immediately) is a different
/// transaction shape entirely — a live request/reply, not a durable queued
/// background one — so it uses `sendMessageData` instead, which requires
/// `isReachable` and fails fast rather than queuing. That's the right
/// tradeoff here: a query answered minutes later, after the nurse has moved
/// on, isn't useful the way a delayed note capture still is.
@MainActor
final class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()

    enum AskError: LocalizedError {
        case notReachable
        case invalidReply

        var errorDescription: String? {
            switch self {
            case .notReachable:
                return "Can't reach your phone right now. Make sure the Nursify app is open nearby and try again."
            case .invalidReply:
                return "Got an unexpected reply from your phone. Try again."
            }
        }
    }

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

    /// Sends a single spoken query to the phone and waits for its answer.
    func ask(fileAt url: URL) async throws -> AskResponse {
        guard let session, session.isReachable else { throw AskError.notReachable }
        let audioData = try Data(contentsOf: url)

        return try await withCheckedThrowingContinuation { continuation in
            session.sendMessageData(audioData) { replyData in
                guard let response = try? JSONDecoder().decode(AskResponse.self, from: replyData) else {
                    continuation.resume(throwing: AskError.invalidReply)
                    return
                }
                continuation.resume(returning: response)
            } errorHandler: { error in
                continuation.resume(throwing: error)
            }
        }
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
