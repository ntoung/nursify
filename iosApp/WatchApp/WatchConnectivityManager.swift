import Foundation
import WatchConnectivity

/// Hands recorded memos to the phone via Watch Connectivity's durable
/// file-transfer queue. `transferFile` (not `sendMessage`) persists and
/// retries across relaunches and out-of-range gaps, so a memo recorded off
/// the phone's Bluetooth/WiFi range still reaches it once back in range —
/// matching REQUIREMENTS.md's "queued" capture model.
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

    func send(fileAt url: URL) {
        session?.transferFile(url, metadata: nil)
        refreshPendingCount()
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
