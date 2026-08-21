import Foundation
import WatchConnectivity

/// Ships each recorded clip to the phone over Watch Connectivity's durable file
/// queue (persists and retries across relaunches and out-of-range gaps), and
/// receives the phone's durable result back to update the on-watch capture
/// list. One transaction shape for everything now - note or question, the watch
/// just sends audio and shows whatever the phone reports back. See
/// WatchConnectivityReceiver on the phone side.
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

    /// Sends a recorded clip to the phone, tagged with the capture id so the
    /// phone's result can be matched back to the right row.
    @discardableResult
    func send(fileAt url: URL, captureId: UUID) -> WCSessionFileTransfer? {
        guard let session else { return nil }
        let transfer = session.transferFile(url, metadata: ["captureId": captureId.uuidString])
        refreshPendingCount()
        return transfer
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

    // The phone's durable result for a capture - decode and hand to the store to
    // fill in the matching row.
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard userInfo["type"] as? String == "captureResult",
              let data = userInfo["payload"] as? Data,
              let result = try? JSONDecoder().decode(WatchCaptureResult.self, from: data) else { return }
        Task { @MainActor in WatchCaptureStore.shared.apply(result) }
    }
}
