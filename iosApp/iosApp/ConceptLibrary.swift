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

    // MARK: - Offline reads (mirror the backend's query semantics)

    /// Case-insensitive substring match on the concept name or any of its
    /// aliases — the same matching the backend's `search()` performs, so
    /// medical abbreviations (STEMI, NTG, EKG, …) resolve offline too.
    func search(_ query: String) -> [ConceptSummary] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }
        return concepts.compactMap { concept in
            let nameMatch = concept.name.lowercased().contains(q)
            let aliasMatch = concept.aliases.first { $0.text.lowercased().contains(q) }
            guard nameMatch || aliasMatch != nil else { return nil }
            var summary = Self.summary(concept)
            // Surface the matched alias only when the name itself didn't match,
            // so brand/abbreviation searches show the term the nurse typed.
            if !nameMatch, let aliasMatch { summary.matchedAlias = aliasMatch.text }
            return summary
        }
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
