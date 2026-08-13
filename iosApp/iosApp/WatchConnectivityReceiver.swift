import Foundation
import WatchConnectivity

/// Receives voice notes recorded on the Watch app (WatchApp/) and finishes
/// them on the phone: on-device transcription, then handed to AppState as a
/// pending draft so the nurse runs it through the same review/PHI-
/// acknowledgment gate as any other capture before it's saved. See
/// REQUIREMENTS.md "Voice notes via iPhone and... Apple Watch (short memos
/// captured on watch, queued and finished/transcribed on phone via Watch
/// Connectivity)."
///
/// A watch note can be built from several recordings (WatchNoteDraft on the
/// watch side). Each clip arrives as its own file tagged with a shared
/// `sessionId` + `sequence`; a separate `transferUserInfo` "session complete"
/// marker (sent when the nurse taps Done) carries the total clip count. File
/// and userInfo transfers are independent queues with no ordering guarantee
/// between them, so a session's clips are buffered here and only joined/
/// surfaced once the buffer actually holds (or has given up on) every clip
/// the completion marker says to expect — never on a partial buffer, so a
/// still-arriving note is never shown to the nurse half-finished.
@MainActor
final class WatchConnectivityReceiver: NSObject, ObservableObject {
    static let shared = WatchConnectivityReceiver()

    weak var appState: AppState?

    private struct SessionBuffer {
        var transcriptsBySequence: [Int: String] = [:]
        var failedSequences: Set<Int> = []
        var expectedCount: Int?

        var receivedCount: Int { transcriptsBySequence.count + failedSequences.count }
    }

    private var sessionBuffers: [String: SessionBuffer] = [:]

    private let session: WCSession? = WCSession.isSupported() ? .default : nil

    override init() {
        super.init()
        session?.delegate = self
        session?.activate()
    }

    private func handleReceivedFile(at url: URL, sessionId: String, sequence: Int) {
        Task {
            defer { try? FileManager.default.removeItem(at: url) }
            let transcript = try? await SpeechCapture.transcribeFile(at: url)
            let trimmed = transcript?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let trimmed, !trimmed.isEmpty {
                sessionBuffers[sessionId, default: SessionBuffer()].transcriptsBySequence[sequence] = trimmed
            } else {
                // Transcription failure or silence has nowhere good to surface
                // synchronously (the phone app may not even be in the
                // foreground when this runs) — counted as "heard back from" so
                // the session can still complete, just without this clip.
                sessionBuffers[sessionId, default: SessionBuffer()].failedSequences.insert(sequence)
            }
            tryFlush(sessionId)
        }
    }

    private func markSessionComplete(sessionId: String, totalCount: Int) {
        sessionBuffers[sessionId, default: SessionBuffer()].expectedCount = totalCount
        tryFlush(sessionId)
    }

    private func tryFlush(_ sessionId: String) {
        guard let buffer = sessionBuffers[sessionId],
              let expected = buffer.expectedCount,
              buffer.receivedCount >= expected else { return }
        sessionBuffers.removeValue(forKey: sessionId)

        let joined = buffer.transcriptsBySequence
            .sorted { $0.key < $1.key }
            .map(\.value)
            .joined(separator: " ")
        guard !joined.isEmpty else { return }
        appState?.pendingWatchDrafts.append(joined)
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
        guard let sessionId = file.metadata?["sessionId"] as? String,
              let sequence = file.metadata?["sequence"] as? Int else { return }
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        guard (try? FileManager.default.copyItem(at: file.fileURL, to: destination)) != nil else { return }
        Task { @MainActor in
            WatchConnectivityReceiver.shared.handleReceivedFile(at: destination, sessionId: sessionId, sequence: sequence)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard userInfo["type"] as? String == "sessionComplete",
              let sessionId = userInfo["sessionId"] as? String,
              let totalCount = userInfo["totalCount"] as? Int else { return }
        Task { @MainActor in
            WatchConnectivityReceiver.shared.markSessionComplete(sessionId: sessionId, totalCount: totalCount)
        }
    }
}
