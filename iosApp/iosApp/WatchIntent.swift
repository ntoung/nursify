import Foundation

/// Decides whether a transcribed Watch utterance is a definition *question*
/// ("what is X", "what does X stand for", "define X") or a note to save.
///
/// A note is the default; only an utterance that clearly opens with a question
/// phrase is treated as a lookup, so ordinary dictation that merely mentions a
/// concept ("started patient on Lasix") still becomes a note. Pure and
/// string-only so it's unit-tested without speech or connectivity.
enum WatchIntent {
    private static let questionPatterns: [NSRegularExpression] = [
        // "what is/what's/what are ..."
        make(#"^\s*what('?s| is| are)\b"#),
        // "what does X stand for / mean"
        make(#"^\s*what\s+does\b.*\b(stand\s+for|means?)\b"#),
        // "define X" / "definition of X" / "meaning of X"
        make(#"^\s*(define|definition\s+of|meaning\s+of)\b"#)
    ]

    /// True when the utterance opens like a definition question.
    static func isQuestion(_ transcript: String) -> Bool {
        let range = NSRange(transcript.startIndex..<transcript.endIndex, in: transcript)
        return questionPatterns.contains { $0.firstMatch(in: transcript, range: range) != nil }
    }

    private static func make(_ pattern: String) -> NSRegularExpression {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }
}
