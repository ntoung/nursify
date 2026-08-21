import Foundation
import WatchConnectivity

/// Receives Watch-recorded clips and does the work the watch can't: on-device
/// transcription, then routing. There's one entry point on the watch now - the
/// nurse just talks - so the phone decides what the utterance was:
///
/// - a definition *question* ("what is X", "what does X stand for") -> look the
///   term up in the bundled concept library and answer;
/// - anything else -> a note, auto-saved to the journal.
///
/// Either way the phone sends a durable result back so the watch can fill in
/// its capture row (see WatchCaptureResult / WatchCaptureStore). Auto-saved
/// notes still get run through the on-device PHIScreener; a hit doesn't block
/// the save (the nurse chose auto-save) but is flagged on the note and the
/// watch row so possible patient info isn't stored silently.
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

    private func handleReceivedFile(at url: URL, captureId: String) {
        Task {
            defer { try? FileManager.default.removeItem(at: url) }
            let result = await process(fileAt: url, captureId: captureId)
            sendResult(result)
        }
    }

    private func process(fileAt url: URL, captureId: String) async -> WatchCaptureResult {
        let transcript: String
        do {
            transcript = try await SpeechCapture.transcribeFile(at: url)
        } catch {
            return WatchCaptureResult(
                captureId: captureId, kind: .failed,
                title: "Couldn't transcribe",
                detail: "That recording couldn't be transcribed. Try again, a bit closer to the mic.",
                phiFlagged: false
            )
        }

        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return WatchCaptureResult(
                captureId: captureId, kind: .failed,
                title: "Nothing heard",
                detail: "No speech was detected in that recording. Try again.",
                phiFlagged: false
            )
        }

        if WatchIntent.isQuestion(trimmed) {
            return resolveDefinition(for: trimmed, captureId: captureId)
        } else {
            return await saveNote(trimmed, captureId: captureId)
        }
    }

    // MARK: Question -> definition (resolved offline against the bundled library)

    private func resolveDefinition(for transcript: String, captureId: String) -> WatchCaptureResult {
        guard let match = ConceptLibrary.shared.mentions(in: transcript).first else {
            return WatchCaptureResult(
                captureId: captureId, kind: .definition,
                title: "No match",
                detail: "Couldn't find that term in the library. Try saying just the term.",
                phiFlagged: false
            )
        }
        // Count the watch lookup toward "Concepts viewed", like opening a
        // concept on the phone does.
        let conceptId = match.conceptId
        Task { await appState?.recordConceptView(conceptId: conceptId) }

        let detail = [match.shortExplanation, match.longExplanation].compactMap { $0 }.first ?? ""
        return WatchCaptureResult(
            captureId: captureId, kind: .definition,
            title: match.conceptName, detail: detail, phiFlagged: false
        )
    }

    // MARK: Note -> auto-saved journal entry

    private func saveNote(_ transcript: String, captureId: String) async -> WatchCaptureResult {
        let phiFlagged = !PHIScreener.scan(transcript).isEmpty
        await appState?.createNote(transcript: transcript, device: .watch, phiReviewed: false, phiFlagged: phiFlagged)
        return WatchCaptureResult(
            captureId: captureId, kind: .note,
            title: "Note saved", detail: transcript, phiFlagged: phiFlagged
        )
    }

    private func sendResult(_ result: WatchCaptureResult) {
        guard let session, let data = try? JSONEncoder().encode(result) else { return }
        // Durable so the watch always gets its answer/confirmation, even if it
        // was briefly out of range when the clip was processed.
        session.transferUserInfo(["type": "captureResult", "payload": data])
    }
}

extension WatchConnectivityReceiver: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    // WatchConnectivity deletes the delivered temp file as soon as this method
    // returns, so copy it somewhere durable before the async transcription step.
    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        guard let captureId = file.metadata?["captureId"] as? String else { return }
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        guard (try? FileManager.default.copyItem(at: file.fileURL, to: destination)) != nil else { return }
        Task { @MainActor in
            WatchConnectivityReceiver.shared.handleReceivedFile(at: destination, captureId: captureId)
        }
    }
}
