import Foundation

/// The phone's durable reply to a Watch capture: what the phone did with the
/// clip once it transcribed it, sent back so the Watch can fill in the matching
/// row in its capture list. Duplicated verbatim in the Watch target (no shared
/// framework between the two here; the type is tiny).
struct WatchCaptureResult: Codable {
    enum Kind: String, Codable {
        case note        // saved to the journal
        case definition  // answered a "what is..." question
        case failed      // couldn't transcribe / nothing heard
    }

    let captureId: String
    let kind: Kind
    /// Headline for the row: "Note saved", the term name, or a failure headline.
    let title: String
    /// Full text for the detail screen: the note transcript, the definition, or
    /// the failure reason.
    let detail: String
    /// Note only: the on-device PHI screener flagged possible patient info.
    let phiFlagged: Bool
}
