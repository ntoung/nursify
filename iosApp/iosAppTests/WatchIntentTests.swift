import XCTest
@testable import iosApp

/// Covers the note-vs-question routing for a Watch utterance. The transcription
/// itself is an OS service (tested only on device); this is the pure decision
/// that sits on top of the transcript.
final class WatchIntentTests: XCTestCase {

    func testQuestionOpeners() {
        for q in [
            "what is sepsis",
            "What's a TAVR",
            "what are the signs of stroke",
            "what does TAVR stand for",
            "what does BNP mean",
            "define tachycardia",
            "definition of afterload",
            "meaning of NPO"
        ] {
            XCTAssertTrue(WatchIntent.isQuestion(q), "should be a question: \(q)")
        }
    }

    func testNotesAreNotQuestions() {
        for note in [
            "patient in room 4 is stable",
            "started patient on Lasix, monitor potassium",
            "what a shift, bed 12 finally settled",   // "what a", not "what is"
            "remember to chart the BNP result",
            "TAVR patient tolerating diet"
        ] {
            XCTAssertFalse(WatchIntent.isQuestion(note), "should be a note: \(note)")
        }
    }

    func testLeadingWhitespaceAndCaseIgnored() {
        XCTAssertTrue(WatchIntent.isQuestion("   WHAT IS afib"))
        XCTAssertTrue(WatchIntent.isQuestion("Define bradycardia"))
    }
}
