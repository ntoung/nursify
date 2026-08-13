import Foundation
import WatchConnectivity

/// Receives voice memos recorded on the Watch app (WatchApp/) and finishes
/// them on the phone: on-device transcription, then handed to AppState as a
/// pending draft so the nurse runs it through the same review/PHI-
/// acknowledgment gate as any other capture before it's saved. See
/// REQUIREMENTS.md "Voice notes via iPhone and... Apple Watch (short memos
/// captured on watch, queued and finished/transcribed on phone via Watch
/// Connectivity)."
@MainActor
final class WatchConnectivityReceiver: NSObject, ObservableObject {
    static let shared = WatchConnectivityReceiver()

    weak var appState: AppState?

    private let session: WCSession? = WCSession.isSupported() ? .default : nil

    override init() {
        super.init()
        session?.delegate = self
        session?.activate()
    }

    private func handleReceivedFile(at url: URL) {
        Task {
            defer { try? FileManager.default.removeItem(at: url) }
            // A transcription failure here (permission never granted, no
            // speech detected, on-device model unavailable) has nowhere good
            // to surface synchronously — the phone app may not even be in the
            // foreground when this runs — so the memo is silently dropped
            // rather than risk mis-saving something the nurse never reviewed.
            guard let transcript = try? await SpeechCapture.transcribeFile(at: url),
                  !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            appState?.pendingWatchDraft = transcript
        }
    }
}

extension WatchConnectivityReceiver: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    // WatchConnectivity deletes the delivered temp file as soon as this
    // method returns, so copy it somewhere durable before handing off to the
    // async transcription step.
    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        guard (try? FileManager.default.copyItem(at: file.fileURL, to: destination)) != nil else { return }
        Task { @MainActor in
            WatchConnectivityReceiver.shared.handleReceivedFile(at: destination)
        }
    }
}
