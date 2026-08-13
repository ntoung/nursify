import Foundation

/// A single possible PHI hit surfaced to the nurse for review.
struct PHIFinding: Identifiable, Equatable {
    let id = UUID()
    let category: String
    let matchedText: String

    static func == (lhs: PHIFinding, rhs: PHIFinding) -> Bool {
        lhs.category == rhs.category && lhs.matchedText == rhs.matchedText
    }
}

/// On-device, regex-based heuristic PHI scanner (REQUIREMENTS.md "Privacy
/// guardrail"). Flags likely patient-identifying content for the nurse to
/// review before saving; it never auto-redacts. This is intentionally a
/// heuristic, not NLP/ML - it will have false positives and false negatives
/// (e.g. it won't catch spoken phrasing like "68-year-old in bed 12" unless
/// it matches one of the patterns below). That's an accepted MVP limitation.
enum PHIScreener {
    private struct Pattern {
        let category: String
        let regex: NSRegularExpression
    }

    private static let patterns: [Pattern] = [
        Pattern(category: "Possible phone number", regex: make(#"\b\d{3}[-.\s]\d{3}[-.\s]\d{4}\b"#)),
        Pattern(category: "Possible SSN", regex: make(#"\b\d{3}-\d{2}-\d{4}\b"#)),
        Pattern(category: "Possible MRN", regex: make(#"\b(?:MRN|medical record\s*(?:#|number))\s*[:#]?\s*\d+\b"#)),
        Pattern(category: "Possible DOB", regex: make(#"\b(?:DOB|date of birth|born on)\b[^.\n]{0,20}"#)),
        Pattern(category: "Possible room/bed number", regex: make(#"\b(?:room|bed)\s*#?\s*\d{1,4}\b"#)),
        Pattern(category: "Possible name", regex: make(#"\b(?:Mr|Mrs|Ms|Miss|Dr)\.?\s+[A-Z][a-z]+\b"#)),
        Pattern(category: "Possible name", regex: make(#"\bpatient\s+[A-Z][a-z]+(?:\s+[A-Z][a-z]+)?\b"#)),
        Pattern(category: "Possible email address", regex: make(#"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b"#))
    ]

    private static func make(_ pattern: String) -> NSRegularExpression {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }

    static func scan(_ text: String) -> [PHIFinding] {
        var findings: [PHIFinding] = []
        var seen = Set<String>()
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)

        for pattern in patterns {
            pattern.regex.enumerateMatches(in: text, range: fullRange) { match, _, _ in
                guard let match, let range = Range(match.range, in: text) else { return }
                let matchedText = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !matchedText.isEmpty else { return }
                let key = "\(pattern.category)|\(matchedText.lowercased())"
                guard !seen.contains(key) else { return }
                seen.insert(key)
                findings.append(PHIFinding(category: pattern.category, matchedText: matchedText))
            }
        }

        return findings
    }
}
