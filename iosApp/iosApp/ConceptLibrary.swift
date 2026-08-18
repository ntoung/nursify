import Foundation

/// The real, production concept corpus — **not mock data**.
///
/// The full library ships inside the app bundle as `ConceptLibrary.json`
/// (generated from the backend seed data; regenerate with
/// `scripts/refresh-concept-library.sh`), so search, category browsing, and
/// concept detail all work fully offline with zero network dependency. This
/// matters for real clinical use on spotty hospital Wi-Fi.
///
/// When the backend is reachable, `refresh()` pulls the latest snapshot in one
/// request and replaces both the in-memory copy and an on-disk override that
/// takes precedence over the bundled file on the next launch. Concept content
/// is therefore served locally and always available; the network only ever
/// makes it *fresher*, never *required*.
@MainActor
final class ConceptLibrary: ObservableObject {
    static let shared = ConceptLibrary()

    @Published private(set) var concepts: [Concept]
    private var byId: [UUID: Concept]
    private let api: APIClient

    /// Where a refreshed snapshot is persisted so it survives relaunch and
    /// supersedes the (older) bundled file until the next successful refresh.
    private static let snapshotURL: URL? = {
        try? FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("ConceptLibrary.json")
    }()

    init(api: APIClient = .shared) {
        self.api = api
        let loaded = ConceptLibrary.loadPersisted() ?? ConceptLibrary.loadBundled()
        self.concepts = loaded
        self.byId = Dictionary(loaded.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// A bounded, high-value slice of the corpus for
    /// `SFSpeechRecognitionRequest.contextualStrings`. That API is meant for a
    /// modest set of phrases, not a full ~1,300-term corpus, so we prioritize
    /// the terms the recognizer is least likely to know on its own - brand
    /// names first, then drug names, then abbreviations/nicknames and other
    /// hard, pronunciation-bearing terms - deduplicate, and cap the list. The
    /// long tail is handled after recording by `correctMedicalTerms(in:)`.
    var contextualStrings: [String] {
        var result: [String] = []
        var seen = Set<String>()
        func add(_ s: String) {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty, seen.insert(t.lowercased()).inserted else { return }
            result.append(t)
        }
        for c in concepts { for a in c.aliases where a.type == .brandName { add(a.text) } }
        for c in concepts where c.type == .medication { add(c.name) }
        for c in concepts { for a in c.aliases where a.type == .acronym || a.type == .nickname { add(a.text) } }
        for c in concepts where c.type != .medication && c.pronunciation != nil { add(c.name) }
        return Array(result.prefix(Self.maxContextualStrings))
    }

    private static let maxContextualStrings = 500

    // MARK: - Post-recording correction

    /// Distinctive single-word terms (drug/brand/abbrev names and other hard,
    /// pronunciation-bearing words, length >= 5) used to snap ASR near-misses
    /// back to real terms. Short/common words are excluded so ordinary English
    /// is left alone.
    private var distinctiveTerms: [String] {
        var seen = Set<String>()
        var out: [String] = []
        func add(_ s: String) {
            guard !s.contains(" "), s.count >= 5, seen.insert(s.lowercased()).inserted else { return }
            out.append(s)
        }
        for c in concepts {
            if c.type == .medication || c.pronunciation != nil { add(c.name) }
            for a in c.aliases { add(a.text) }
        }
        return out
    }

    /// Nudges obvious transcription near-misses toward real medical terms once a
    /// recording finishes - a backstop for the long tail that can't fit in
    /// `contextualStrings`. Deliberately conservative: only single tokens of
    /// length >= 5 within a small, length-scaled edit distance of a distinctive
    /// term (and sharing its first letter) are replaced, so common English is
    /// untouched. The nurse still reviews the transcript before saving.
    func correctMedicalTerms(in text: String) -> String {
        guard !text.isEmpty else { return text }
        let targets = distinctiveTerms
        guard !targets.isEmpty,
              let regex = try? NSRegularExpression(pattern: "[A-Za-z][A-Za-z'’-]{4,}")
        else { return text }

        let ns = text as NSString
        var result = ""
        var last = 0
        regex.enumerateMatches(in: text, range: NSRange(location: 0, length: ns.length)) { match, _, _ in
            guard let match else { return }
            let range = match.range
            result += ns.substring(with: NSRange(location: last, length: range.location - last))
            let token = ns.substring(with: range)
            result += Self.bestCorrection(for: token, targets: targets) ?? token
            last = range.location + range.length
        }
        result += ns.substring(from: last)
        return result
    }

    private static func bestCorrection(for token: String, targets: [String]) -> String? {
        let lower = token.lowercased()
        let n = lower.count
        let maxDist = n <= 6 ? 1 : 2
        var best: String?
        var bestDist = maxDist + 1
        for target in targets {
            let t = target.lowercased()
            if t == lower { return nil }              // token is already a real term
            if abs(t.count - n) > maxDist { continue }
            if t.first != lower.first { continue }    // prefilter; also guards against wild swaps
            let d = levenshtein(lower, t, cap: maxDist)
            if d < bestDist { bestDist = d; best = target }
        }
        return bestDist <= maxDist ? best : nil
    }

    private static func levenshtein(_ a: String, _ b: String, cap: Int) -> Int {
        let a = Array(a), b = Array(b)
        let n = a.count, m = b.count
        if abs(n - m) > cap { return cap + 1 }
        var prev = Array(0...m)
        for i in 1...n {
            var cur = [i] + Array(repeating: 0, count: m)
            var rowMin = i
            for j in 1...m {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                cur[j] = Swift.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
                rowMin = Swift.min(rowMin, cur[j])
            }
            if rowMin > cap { return cap + 1 }
            prev = cur
        }
        return prev[m]
    }

    // MARK: - Offline reads (mirror the backend's query semantics)

    /// Relevance-ranked, typo-tolerant search over each concept's name,
    /// aliases, and (low-weight) tags. Every concept is scored; those with any
    /// signal are returned best-match-first, so exact and prefix hits lead,
    /// multi-word queries match regardless of order, and misspellings still
    /// resolve. Mirrors the backend `ConceptSearch.rank` scoring so online and
    /// offline agree.
    ///
    /// Tiers (per concept, strongest signal wins):
    ///   name  exact 1000 / prefix 700 / substring 400
    ///   alias exact  900 / prefix 600 / substring 350
    ///   all query words present 500, else partial coverage prorated to 250
    ///   whole-query tag exact 150 / substring 60   (a category is a weak hint)
    ///   typo (Levenshtein) on ≥4-char words         up to 170
    /// Ties break toward shorter (more specific) names; results are capped.
    func search(_ query: String) -> [ConceptSummary] {
        let q = Self.normalizedForSearch(query)
        guard !q.isEmpty else { return [] }
        let qTokens = Self.searchTokens(q)
        let fuzzyTokens = qTokens.filter { $0.count >= 4 }
        // A single character matches only names/aliases that START with it - a
        // 1-char substring/token match would return most of the corpus. From
        // two characters up, full substring/token/tag scoring runs.
        let allowSubstring = q.count >= 2

        var scored: [(summary: ConceptSummary, score: Double)] = []
        scored.reserveCapacity(concepts.count)

        for concept in concepts {
            let name = Self.normalizedForSearch(concept.name)
            let aliases = concept.aliases.map { (text: $0.text, norm: Self.normalizedForSearch($0.text)) }
            let tags = concept.tags.map { Self.normalizedForSearch($0) }

            var score = 0.0

            // Whole-query name tier.
            if name == q { score = 1000 }
            else if name.hasPrefix(q) { score = 700 }
            else if allowSubstring && name.contains(q) { score = 400 }

            // Whole-query alias tier (remember the strongest matching alias so
            // the UI can surface the term the nurse actually typed).
            var bestAlias: String?
            var bestAliasScore = 0.0
            for a in aliases {
                let s = a.norm == q ? 900.0 : a.norm.hasPrefix(q) ? 600.0 : (allowSubstring && a.norm.contains(q)) ? 350.0 : 0.0
                if s > bestAliasScore { bestAliasScore = s; bestAlias = a.text }
            }
            score = max(score, bestAliasScore)

            // Multi-word coverage: how many query words appear anywhere (name,
            // alias, or tag). Full coverage ranks like a strong name hit.
            if allowSubstring && !qTokens.isEmpty {
                let matched = qTokens.reduce(into: 0) { acc, t in
                    if name.contains(t)
                        || aliases.contains(where: { $0.norm.contains(t) })
                        || tags.contains(where: { $0.contains(t) }) { acc += 1 }
                }
                if matched > 0 {
                    let coverage = matched == qTokens.count ? 500.0 : 250.0 * Double(matched) / Double(qTokens.count)
                    score = max(score, coverage)
                }
            }

            // Category tags — a weak hint, well below any name/alias match.
            if allowSubstring {
                for tag in tags {
                    if tag == q { score = max(score, 150) }
                    else if tag.contains(q) { score = max(score, 60) }
                }
            }

            // Typo tolerance: capped Levenshtein per word, gated to ≥4-char
            // words (so short acronyms like "PE"/"MI" never fuzzy-match) with a
            // same-first-letter prefilter that also guards against wild swaps.
            if !fuzzyTokens.isEmpty {
                let candidates = Self.searchTokens(name) + aliases.flatMap { Self.searchTokens($0.norm) }
                for qt in fuzzyTokens {
                    let maxDist = qt.count <= 6 ? 1 : 2
                    for cand in candidates
                    where cand.count >= 4 && cand.first == qt.first && abs(cand.count - qt.count) <= maxDist {
                        let d = Self.levenshtein(qt, cand, cap: maxDist)
                        if d <= maxDist { score = max(score, 240 - Double(d) * 70) }
                    }
                }
            }

            guard score > 0 else { continue }

            var summary = Self.summary(concept)
            // Surface the matched alias only when the name itself didn't
            // substring-match, so brand/abbreviation hits show what was typed.
            if !name.contains(q), let bestAlias, bestAliasScore > 0 { summary.matchedAlias = bestAlias }
            // Nudge shorter (more specific) names above longer ones at a tie.
            scored.append((summary, score - Double(name.count) * 0.1))
        }

        return scored
            .sorted { $0.score != $1.score ? $0.score > $1.score : $0.summary.name.count < $1.summary.name.count }
            .prefix(60)
            .map(\.summary)
    }

    /// Lowercased + diacritic-folded, for accent/case-insensitive matching.
    private static func normalizedForSearch(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Split into alphanumeric word tokens, dropping punctuation/whitespace.
    private static func searchTokens(_ s: String) -> [String] {
        s.split { !$0.isLetter && !$0.isNumber }.map(String.init)
    }

    func byCategory(_ type: ConceptType) -> [ConceptSummary] {
        concepts.filter { $0.type == type }.map(Self.summary)
    }

    func concept(id: UUID) -> Concept? { byId[id] }

    /// Resolve a term to a concept by exact (case-insensitive) name first, then
    /// by any exact alias — mirrors the backend's `findByNameOrAliasIgnoreCase`
    /// so chart lookup matches brand names and abbreviations ("Lasix", "ASA")
    /// too, and offline results stay identical to the server's.
    func concept(named name: String) -> Concept? {
        let term = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let byName = concepts.first(where: { $0.name.caseInsensitiveCompare(term) == .orderedSame }) {
            return byName
        }
        return concepts.first { concept in
            concept.aliases.contains { $0.text.caseInsensitiveCompare(term) == .orderedSame }
        }
    }

    /// Chart lookup served entirely from the local corpus. Mirrors the
    /// backend's stateless `/chart-lookup` (exact case-insensitive name match →
    /// short explanation + mechanism), so it works fully offline and returns
    /// the same result the server would. Unknown meds get an honest
    /// "not curated" placeholder rather than a fabricated explanation.
    func chartLookup(chiefComplaints: [String], medicationNames: [String]) -> [MedicationExplanation] {
        medicationNames.map { name in
            if let concept = concept(named: name) {
                return MedicationExplanation(
                    name: concept.name,
                    relatedComplaints: chiefComplaints,
                    shortExplanation: concept.shortExplanation,
                    longExplanation: concept.sections.mechanism,
                    found: true
                )
            }
            return MedicationExplanation(
                name: name,
                relatedComplaints: chiefComplaints,
                shortExplanation: "Explanation not yet available for \(name) — this concept hasn't been curated yet.",
                longExplanation: nil,
                found: false
            )
        }
    }

    /// Offline concept-mention detection for a note transcript — mirrors the
    /// backend's `ConceptRepository.findMentions` (whole-term name/alias
    /// matching), so a note captured offline surfaces its concepts immediately
    /// and those mentions line up with what the server computes on sync.
    func mentions(in transcript: String) -> [MentionedConcept] {
        concepts.compactMap { concept in
            let matched = Self.containsWholeTerm(transcript, concept.name)
                || concept.aliases.contains { Self.containsWholeTerm(transcript, $0.text) }
            guard matched else { return nil }
            return MentionedConcept(
                id: concept.id,
                conceptId: concept.id,
                conceptName: concept.name,
                type: concept.type,
                shortExplanation: concept.shortExplanation,
                longExplanation: Self.longExplanation(for: concept)
            )
        }
    }

    /// Whole-term (not mid-word) case-insensitive match, matching the backend's
    /// regex so short aliases like "PE"/"HD" don't fire inside unrelated words.
    private static func containsWholeTerm(_ text: String, _ term: String) -> Bool {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let pattern = "(?<![A-Za-z0-9])\(NSRegularExpression.escapedPattern(for: trimmed))(?![A-Za-z0-9])"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return false }
        return regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    /// The primary detail field per type — mirrors the backend's
    /// `longExplanationFor` so offline mentions carry the same "Details" text.
    private static func longExplanation(for concept: Concept) -> String? {
        let s = concept.sections
        switch concept.type {
        case .medication: return s.nursingImplications ?? s.sideEffects
        case .procedure: return s.whatToMonitor ?? s.targetConcern
        case .condition: return s.presentation ?? s.typicalTreatments
        case .labValue: return s.abnormalMeaning ?? s.normalRange
        case .equipment: return s.careConsiderations ?? s.purpose
        case .protocolOrderSet: return s.steps ?? s.triggerCriteria
        case .anatomy: return nil
        case .assessmentTool: return s.steps ?? s.purpose
        }
    }

    // MARK: - Snapshot sync

    /// Pull the latest corpus from the backend and replace the local copy.
    /// Silently no-ops when the backend is unreachable (offline) or returns an
    /// empty set — the bundled/persisted library keeps serving in that case.
    @discardableResult
    func refresh() async -> Bool {
        guard let fresh = try? await api.allConcepts(), !fresh.isEmpty else { return false }
        concepts = fresh
        byId = Dictionary(fresh.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        persist(fresh)
        return true
    }

    // MARK: - Helpers

    private static func summary(_ c: Concept) -> ConceptSummary {
        ConceptSummary(id: c.id, type: c.type, name: c.name, sideEffectsPreview: c.sections.sideEffects)
    }

    private static func loadBundled() -> [Concept] {
        guard let url = Bundle.main.url(forResource: "ConceptLibrary", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            assertionFailure("ConceptLibrary.json missing from the app bundle")
            return []
        }
        do {
            return try JSONDecoder().decode([Concept].self, from: data)
        } catch {
            assertionFailure("ConceptLibrary.json failed to decode: \(error)")
            return []
        }
    }

    private static func loadPersisted() -> [Concept]? {
        guard let url = snapshotURL,
              let data = try? Data(contentsOf: url),
              let concepts = try? JSONDecoder().decode([Concept].self, from: data),
              !concepts.isEmpty else { return nil }
        return concepts
    }

    private func persist(_ concepts: [Concept]) {
        guard let url = ConceptLibrary.snapshotURL,
              let data = try? JSONEncoder().encode(concepts) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
