import Foundation

/// Pure session-assembly logic for Watch-recorded notes: buffers each clip's
/// transcription per session, waits for the "session complete" marker, then
/// joins the clips in sequence order.
///
/// Extracted from `WatchConnectivityReceiver` so this - the part that can
/// actually regress - is unit-testable without a live `WCSession` or the
/// on-device speech recognizer, neither of which runs in the Simulator/CI. The
/// receiver keeps only the thin WatchConnectivity glue and feeds transcription
/// results in here.
///
/// File and userInfo transfers are independent queues with no ordering
/// guarantee between them, so a session is only surfaced once the buffer holds
/// (or has given up on) every clip the completion marker says to expect - never
/// on a partial buffer, so a still-arriving note is never shown half-finished.
struct WatchNoteAssembler {

    /// The terminal result of a session once every expected clip has arrived.
    enum Outcome: Equatable {
        /// The note is ready to review. `partialFailure` is true when some (but
        /// not all) clips failed to transcribe, so the caller can warn that the
        /// text is incomplete.
        case ready(text: String, partialFailure: Bool)
        /// Every clip arrived but none could be transcribed (denied permission,
        /// no on-device model, or nothing but silence) - there is nothing to
        /// review, so the note is lost.
        case lost
    }

    private struct SessionBuffer {
        var transcriptsBySequence: [Int: String] = [:]
        var failedSequences: Set<Int> = []
        var expectedCount: Int?

        var receivedCount: Int { transcriptsBySequence.count + failedSequences.count }
    }

    private var buffers: [String: SessionBuffer] = [:]

    /// Records a clip's transcription result. A nil/empty `transcript` counts as
    /// a failed clip (so the session can still complete without it). Returns an
    /// `Outcome` if this clip completes the session, otherwise nil.
    mutating func receiveClip(sessionId: String, sequence: Int, transcript: String?) -> Outcome? {
        let trimmed = transcript?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            buffers[sessionId, default: SessionBuffer()].transcriptsBySequence[sequence] = trimmed
        } else {
            buffers[sessionId, default: SessionBuffer()].failedSequences.insert(sequence)
        }
        return tryFlush(sessionId)
    }

    /// Records how many clips a session should contain. Returns an `Outcome` if
    /// every expected clip is already buffered, otherwise nil.
    mutating func markComplete(sessionId: String, totalCount: Int) -> Outcome? {
        buffers[sessionId, default: SessionBuffer()].expectedCount = totalCount
        return tryFlush(sessionId)
    }

    private mutating func tryFlush(_ sessionId: String) -> Outcome? {
        guard let buffer = buffers[sessionId],
              let expected = buffer.expectedCount,
              buffer.receivedCount >= expected else { return nil }
        buffers.removeValue(forKey: sessionId)

        let joined = buffer.transcriptsBySequence
            .sorted { $0.key < $1.key }
            .map(\.value)
            .joined(separator: " ")

        guard !joined.isEmpty else { return .lost }
        return .ready(text: joined, partialFailure: !buffer.failedSequences.isEmpty)
    }
}
