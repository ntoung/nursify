import XCTest
@testable import iosApp

/// Covers the phone-side assembly of a Watch-recorded voice note: clips arrive
/// as independent transfers (any order), a separate "session complete" marker
/// says how many to expect, and the note is only surfaced once every clip is in
/// - joined in sequence order. This is the logic that can regress; the actual
/// mic capture, Watch Connectivity transfer, and on-device transcription are OS
/// services exercised only on a physical watch.
final class WatchNoteAssemblerTests: XCTestCase {

    // A single-clip note: complete marker after the clip -> ready with the text.
    func testSingleClipReadyAfterCompletion() {
        var a = WatchNoteAssembler()
        XCTAssertNil(a.receiveClip(sessionId: "s", sequence: 1, transcript: "patient in room 4"))
        XCTAssertEqual(a.markComplete(sessionId: "s", totalCount: 1),
                       .ready(text: "patient in room 4", partialFailure: false))
    }

    // Clips can arrive out of order across independent transfer queues; the note
    // must still read in sequence order.
    func testMultipleClipsJoinedInSequenceOrder() {
        var a = WatchNoteAssembler()
        XCTAssertNil(a.receiveClip(sessionId: "s", sequence: 3, transcript: "third"))
        XCTAssertNil(a.receiveClip(sessionId: "s", sequence: 1, transcript: "first"))
        XCTAssertNil(a.markComplete(sessionId: "s", totalCount: 3))
        // Still waiting on clip 2 -> nothing surfaces yet.
        let final = a.receiveClip(sessionId: "s", sequence: 2, transcript: "second")
        XCTAssertEqual(final, .ready(text: "first second third", partialFailure: false))
    }

    // The completion marker can arrive before the clips (independent queues, no
    // ordering guarantee). The note must not surface until the last clip lands.
    func testCompletionBeforeAllClipsWaitsForThem() {
        var a = WatchNoteAssembler()
        XCTAssertNil(a.markComplete(sessionId: "s", totalCount: 2))
        XCTAssertNil(a.receiveClip(sessionId: "s", sequence: 1, transcript: "hello"))
        XCTAssertEqual(a.receiveClip(sessionId: "s", sequence: 2, transcript: "world"),
                       .ready(text: "hello world", partialFailure: false))
    }

    // Every clip failed to transcribe (silence / no on-device model / denied):
    // nothing to review, so the note is reported lost rather than surfaced empty.
    func testAllClipsFailedIsLost() {
        var a = WatchNoteAssembler()
        XCTAssertNil(a.receiveClip(sessionId: "s", sequence: 1, transcript: nil))
        XCTAssertNil(a.receiveClip(sessionId: "s", sequence: 2, transcript: "   "))
        XCTAssertEqual(a.markComplete(sessionId: "s", totalCount: 2), .lost)
    }

    // A partial failure still surfaces the note (with the good clips) but flags
    // that it's incomplete so the caller can warn the nurse.
    func testPartialFailureSurfacesWithFlag() {
        var a = WatchNoteAssembler()
        XCTAssertNil(a.receiveClip(sessionId: "s", sequence: 1, transcript: "vitals stable"))
        XCTAssertNil(a.receiveClip(sessionId: "s", sequence: 2, transcript: nil))
        XCTAssertEqual(a.markComplete(sessionId: "s", totalCount: 3), nil)
        XCTAssertEqual(a.receiveClip(sessionId: "s", sequence: 3, transcript: "call back"),
                       .ready(text: "vitals stable call back", partialFailure: true))
    }

    // Interleaved sessions must not bleed into each other.
    func testConcurrentSessionsStayIsolated() {
        var a = WatchNoteAssembler()
        XCTAssertNil(a.receiveClip(sessionId: "A", sequence: 1, transcript: "alpha"))
        XCTAssertNil(a.receiveClip(sessionId: "B", sequence: 1, transcript: "bravo"))
        XCTAssertEqual(a.markComplete(sessionId: "B", totalCount: 1),
                       .ready(text: "bravo", partialFailure: false))
        XCTAssertEqual(a.markComplete(sessionId: "A", totalCount: 1),
                       .ready(text: "alpha", partialFailure: false))
    }

    // A clip that arrives after its session already flushed starts a fresh
    // session rather than mutating the finished one (defensive - shouldn't
    // happen given the Watch sends one completion marker per session).
    func testClipAfterFlushDoesNotResurrectSession() {
        var a = WatchNoteAssembler()
        _ = a.receiveClip(sessionId: "s", sequence: 1, transcript: "done")
        XCTAssertEqual(a.markComplete(sessionId: "s", totalCount: 1),
                       .ready(text: "done", partialFailure: false))
        // Late straggler: no completion marker for the new buffer -> stays put.
        XCTAssertNil(a.receiveClip(sessionId: "s", sequence: 2, transcript: "late"))
    }
}
