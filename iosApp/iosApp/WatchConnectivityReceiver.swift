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

    /// Session buffering/joining lives in WatchNoteAssembler so it can be
    /// unit-tested without a live WCSession or the speech recognizer.
    private var assembler = WatchNoteAssembler()

    private let session: WCSession? = WCSession.isSupported() ? .default : nil

    override init() {
        super.init()
        session?.delegate = self
        session?.activate()
    }

    private func handleReceivedFile(at url: URL, sessionId: String, sequence: Int) {
        Task {
            defer { try? FileManager.default.removeItem(at: url) }
            // A transcription failure or silence (nil/empty) is counted as
            // "heard back from" by the assembler so the session can still
            // complete, just without this clip - there's nowhere good to
            // surface it synchronously (the phone app may not even be in the
            // foreground when this runs).
            let transcript = try? await SpeechCapture.transcribeFile(at: url)
            if let outcome = assembler.receiveClip(sessionId: sessionId, sequence: sequence, transcript: transcript) {
                apply(outcome)
            }
        }
    }

    private func markSessionComplete(sessionId: String, totalCount: Int) {
        if let outcome = assembler.markComplete(sessionId: sessionId, totalCount: totalCount) {
            apply(outcome)
        }
    }

    private func apply(_ outcome: WatchNoteAssembler.Outcome) {
        switch outcome {
        case .lost:
            // Previously a fully-failed note just vanished with no trace - a
            // nurse would see it marked "sent" on the Watch and then nothing on
            // the phone, unable to tell whether it was still in flight or lost
            // for good. Surfacing it here at least makes the loss visible.
            appState?.errorMessage = "A voice note from your Watch couldn't be transcribed and was lost. Try recording again closer to your phone."
        case .ready(let text, let partialFailure):
            if partialFailure {
                appState?.errorMessage = "Part of a Watch note couldn't be transcribed - review it carefully before saving."
            }
            appState?.pendingWatchDrafts.append(text)
        }
    }

    // MARK: - Ask mode — a single spoken term, answered immediately over
    // `sendMessageData`'s reply handler rather than the queued file/userInfo
    // transfers above. Resolved entirely offline against the bundled concept
    // library (same one Search uses), reusing whole-term mention matching:
    // a query like "what's TAVR" contains "TAVR" as a matchable term the same
    // way a note transcript would, so there's no separate query-parsing path
    // to build or keep in sync with the note side.

    private func handleAskQuery(audioData: Data, replyHandler: @escaping (Data) -> Void) {
        Task {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("m4a")
            defer { try? FileManager.default.removeItem(at: url) }

            let response: AskResponse
            do {
                try audioData.write(to: url)
                let transcript = try await SpeechCapture.transcribeFile(at: url)
                response = resolveAskQuery(transcript: transcript)
            } catch {
                response = AskResponse(
                    found: false,
                    termName: nil,
                    shortExplanation: nil,
                    longExplanation: nil,
                    errorMessage: "Couldn't hear that clearly. Try again."
                )
            }
            replyHandler((try? JSONEncoder().encode(response)) ?? Data())
        }
    }

    private func resolveAskQuery(transcript: String) -> AskResponse {
        guard let match = ConceptLibrary.shared.mentions(in: transcript).first else {
            return AskResponse(found: false, termName: nil, shortExplanation: nil, longExplanation: nil, errorMessage: nil)
        }
        // Fire-and-forget: count the watch lookup toward the "Concepts viewed"
        // usage stat, like opening a concept on the phone does.
        let conceptId = match.conceptId
        Task { await appState?.recordConceptView(conceptId: conceptId) }
        return AskResponse(
            found: true,
            termName: match.conceptName,
            shortExplanation: match.shortExplanation,
            longExplanation: match.longExplanation,
            errorMessage: nil
        )
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

    nonisolated func session(_ session: WCSession, didReceiveMessageData messageData: Data, replyHandler: @escaping (Data) -> Void) {
        Task { @MainActor in
            WatchConnectivityReceiver.shared.handleAskQuery(audioData: messageData, replyHandler: replyHandler)
        }
    }
}
