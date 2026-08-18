import Foundation
import SwiftData
import SwiftUI

/// On-device gamification: badges, points, and levels. See GAMIFICATION_ADR.md
/// for the design rationale — everything here stays local (SwiftData, its own
/// container), computed from an append-only event log rather than scattered
/// counters, and nothing about it syncs to the backend.

// MARK: - Event log

enum GamificationEventType: String, Codable {
    case conceptViewed
    case searchPerformed
    case noteCaptured
    case chartLookupSessionCompleted
    case appForegrounded
    case appBackgrounded
}

@Model
final class GamificationEvent {
    var id: UUID
    var typeRaw: String
    var at: Date
    /// Only set for `.conceptViewed` — which concept, so distinct-concept
    /// badges can count unique ids rather than raw view counts.
    var conceptId: UUID?
    var conceptTypeRaw: String?

    init(type: GamificationEventType, at: Date = Date(), conceptId: UUID? = nil, conceptType: ConceptType? = nil) {
        self.id = UUID()
        self.typeRaw = type.rawValue
        self.at = at
        self.conceptId = conceptId
        self.conceptTypeRaw = conceptType?.rawValue
    }

    var type: GamificationEventType { GamificationEventType(rawValue: typeRaw) ?? .conceptViewed }
    var conceptType: ConceptType? { conceptTypeRaw.flatMap(ConceptType.init(rawValue:)) }
}

@Model
final class UnlockedBadgeRecord {
    var id: UUID
    var badgeId: String
    var unlockedAt: Date

    init(badgeId: String, unlockedAt: Date = Date()) {
        self.id = UUID()
        self.badgeId = badgeId
        self.unlockedAt = unlockedAt
    }
}

// MARK: - Aggregates

/// Everything badges/points/levels are computed from — a pure reduction over
/// the event log (plus, for `specialistCoverageFraction`, a lightweight
/// cross-reference against the concept corpus and the nurse's chosen
/// specialties). Never persisted itself; recomputed on demand.
struct GamificationSnapshot {
    var distinctConceptsByType: [ConceptType: Set<UUID>] = [:]
    var notesCaptured = 0
    var chartLookupSessions = 0
    var searchesPerformed = 0
    var appForegroundedCount = 0
    var totalPoints = 0
    var specialistCoverageFraction: Double = 0

    var distinctConceptsTotal: Int { Set(distinctConceptsByType.values.flatMap { $0 }).count }
    func distinctCount(for type: ConceptType) -> Int { distinctConceptsByType[type]?.count ?? 0 }
}

// MARK: - Points & levels (see GAMIFICATION_ADR.md "Points & levels")

enum GamificationPoints {
    static let conceptViewed = 2
    static let searchPerformed = 1
    static let noteCaptured = 5
    static let chartLookupSessionCompleted = 5
    static let appForegroundedFirstOfDay = 3
}

enum GamificationLevels {
    /// Closed-form curve: `50 × level × (level − 1)`. Tuning, not
    /// architecture — cheap to retune since levels are computed, never stored.
    static func threshold(for level: Int) -> Int { 50 * level * (level - 1) }

    static func level(for points: Int) -> Int {
        var level = 1
        while threshold(for: level + 1) <= points { level += 1 }
        return level
    }

    static func progress(for points: Int) -> (level: Int, pointsIntoLevel: Int, pointsForNextLevel: Int) {
        let level = level(for: points)
        let floor = threshold(for: level)
        let ceiling = threshold(for: level + 1)
        return (level, points - floor, ceiling - floor)
    }
}

// MARK: - Usage summary (Home tab period view)

enum SummaryPeriod: String, CaseIterable, Identifiable {
    case week = "Week"
    case month = "Month"
    case year = "Year"

    var id: String { rawValue }

    /// Trailing window in days, rather than calendar-boundary week/month/
    /// year — simpler, and avoids a nurse opening the app Monday morning to
    /// an almost-empty "this week" right after a busy Sunday.
    var trailingDays: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .year: return 365
        }
    }
}

struct UsageSummary {
    var conceptsViewed = 0
    var searchesPerformed = 0
    var notesCaptured = 0
    var chartLookupSessions = 0
    var activeMinutes = 0
}

// MARK: - Badges

/// Progress toward a badge, for the tap-to-open detail dialog. `current` is
/// shown capped at `target`, but the raw values drive `isComplete`.
struct BadgeProgress {
    let current: Int
    let target: Int
    var isPercent = false

    var fraction: Double { target > 0 ? min(1, Double(current) / Double(target)) : (current > 0 ? 1 : 0) }
    var isComplete: Bool { current >= target }
    /// e.g. "7 / 10" or "60% / 75%".
    var label: String {
        let shown = Swift.min(current, target)
        return isPercent ? "\(shown)% / \(target)%" : "\(shown) / \(target)"
    }
}

struct BadgeDefinition: Identifiable {
    let id: String
    let name: String
    let description: String
    let symbolName: String
    let accentColorHex: String
    let pointBonus: Int
    let isUnlocked: (GamificationSnapshot) -> Bool
    /// Current progress toward the badge, shown in the tap-to-open detail.
    let progress: (GamificationSnapshot) -> BadgeProgress

    var accentColor: Color { Color(hex: accentColorHex) }
}

enum BadgeCatalog {
    static let all: [BadgeDefinition] = [
        BadgeDefinition(
            id: "first-shift", name: "First Shift",
            description: "Opened Nursify for the first time.",
            symbolName: "hand.wave.fill", accentColorHex: "E9A65C", pointBonus: 20,
            isUnlocked: { $0.appForegroundedCount >= 1 },
            progress: { BadgeProgress(current: $0.appForegroundedCount, target: 1) }
        ),
        BadgeDefinition(
            id: "book-worm-bronze", name: "Book Worm",
            description: "Viewed 10 different concepts.",
            symbolName: "book.fill", accentColorHex: "5FA88C", pointBonus: 30,
            isUnlocked: { $0.distinctConceptsTotal >= 10 },
            progress: { BadgeProgress(current: $0.distinctConceptsTotal, target: 10) }
        ),
        BadgeDefinition(
            id: "book-worm-silver", name: "Book Worm II",
            description: "Viewed 50 different concepts.",
            symbolName: "book.fill", accentColorHex: "6FA8DC", pointBonus: 75,
            isUnlocked: { $0.distinctConceptsTotal >= 50 },
            progress: { BadgeProgress(current: $0.distinctConceptsTotal, target: 50) }
        ),
        BadgeDefinition(
            id: "book-worm-gold", name: "Book Worm III",
            description: "Viewed 150 different concepts.",
            symbolName: "book.fill", accentColorHex: "C9A227", pointBonus: 150,
            isUnlocked: { $0.distinctConceptsTotal >= 150 },
            progress: { BadgeProgress(current: $0.distinctConceptsTotal, target: 150) }
        ),
        BadgeDefinition(
            id: "pharmacist-in-training", name: "Pharmacist in Training",
            description: "Viewed 25 different medications.",
            symbolName: "pills.fill", accentColorHex: "B5583B", pointBonus: 50,
            isUnlocked: { $0.distinctCount(for: .medication) >= 25 },
            progress: { BadgeProgress(current: $0.distinctCount(for: .medication), target: 25) }
        ),
        BadgeDefinition(
            id: "procedure-pro", name: "Procedure Pro",
            description: "Viewed 15 different procedures.",
            symbolName: "stethoscope", accentColorHex: "4C6E9C", pointBonus: 50,
            isUnlocked: { $0.distinctCount(for: .procedure) >= 15 },
            progress: { BadgeProgress(current: $0.distinctCount(for: .procedure), target: 15) }
        ),
        BadgeDefinition(
            id: "detective", name: "Detective",
            description: "Viewed 25 different conditions.",
            symbolName: "magnifyingglass", accentColorHex: "8B6BAF", pointBonus: 50,
            isUnlocked: { $0.distinctCount(for: .condition) >= 25 },
            progress: { BadgeProgress(current: $0.distinctCount(for: .condition), target: 25) }
        ),
        BadgeDefinition(
            id: "lab-rat", name: "Lab Rat",
            description: "Viewed 15 different lab values.",
            symbolName: "flask.fill", accentColorHex: "3F8158", pointBonus: 50,
            isUnlocked: { $0.distinctCount(for: .labValue) >= 15 },
            progress: { BadgeProgress(current: $0.distinctCount(for: .labValue), target: 15) }
        ),
        BadgeDefinition(
            id: "by-the-book", name: "By the Book",
            description: "Viewed 10 different protocols.",
            symbolName: "list.clipboard.fill", accentColorHex: "A57C2E", pointBonus: 50,
            isUnlocked: { $0.distinctCount(for: .protocolOrderSet) >= 10 },
            progress: { BadgeProgress(current: $0.distinctCount(for: .protocolOrderSet), target: 10) }
        ),
        BadgeDefinition(
            id: "full-coverage", name: "Full Coverage",
            description: "Viewed at least one concept of every type.",
            symbolName: "checkmark.seal.fill", accentColorHex: "5FA88C", pointBonus: 50,
            isUnlocked: { snapshot in ConceptType.allCases.allSatisfy { snapshot.distinctCount(for: $0) >= 1 } },
            progress: { snapshot in
                BadgeProgress(
                    current: ConceptType.allCases.filter { snapshot.distinctCount(for: $0) >= 1 }.count,
                    target: ConceptType.allCases.count
                )
            }
        ),
        BadgeDefinition(
            id: "specialist", name: "Specialist",
            description: "Viewed 75% of concepts tagged to your specialty.",
            symbolName: "star.fill", accentColorHex: "C9A227", pointBonus: 50,
            isUnlocked: { $0.specialistCoverageFraction >= 0.75 },
            progress: { BadgeProgress(current: Int(($0.specialistCoverageFraction * 100).rounded()), target: 75, isPercent: true) }
        ),
        BadgeDefinition(
            id: "note-taker", name: "Note Taker",
            description: "Captured 10 notes.",
            symbolName: "pencil.and.list.clipboard", accentColorHex: "DE7259", pointBonus: 50,
            isUnlocked: { $0.notesCaptured >= 10 },
            progress: { BadgeProgress(current: $0.notesCaptured, target: 10) }
        ),
        BadgeDefinition(
            id: "making-rounds", name: "Making Rounds",
            description: "Completed 10 medication lookups.",
            symbolName: "figure.walk", accentColorHex: "4C6E9C", pointBonus: 50,
            isUnlocked: { $0.chartLookupSessions >= 10 },
            progress: { BadgeProgress(current: $0.chartLookupSessions, target: 10) }
        ),
    ]

    static func badge(id: String) -> BadgeDefinition? { all.first { $0.id == id } }
}

/// One entry in the transient unlock-dialog queue — a badge or a level-up,
/// never a plain point gain (see GAMIFICATION_ADR.md "UI treatment").
enum GamificationUnlock: Identifiable {
    case badge(BadgeDefinition)
    case levelUp(Int)

    var id: String {
        switch self {
        case .badge(let badge): return "badge-\(badge.id)"
        case .levelUp(let level): return "level-\(level)"
        }
    }
}

// MARK: - Engine

@MainActor
final class GamificationEngine: ObservableObject {
    @Published private(set) var snapshot = GamificationSnapshot()
    @Published private(set) var unlockedBadgeIds: Set<String> = []
    @Published private(set) var level = 1
    @Published var unlockQueue: [GamificationUnlock] = []

    private let modelContext: ModelContext
    private let library: ConceptLibrary
    /// Pushed in by AppState (on launch and after onboarding) rather than
    /// read via a closure back into AppState — avoids capturing a
    /// half-initialized `self` during AppState's own init.
    private var specialties: Set<Specialty> = []

    init(library: ConceptLibrary = .shared) {
        self.library = library
        let schema = Schema([GamificationEvent.self, UnlockedBadgeRecord.self])
        // A local, app-owned store — failure here means the device is out of
        // disk space or similarly unusable, not a recoverable runtime state.
        let container = try! ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: false)])
        self.modelContext = ModelContext(container)

        let persisted = (try? modelContext.fetch(FetchDescriptor<UnlockedBadgeRecord>())) ?? []
        unlockedBadgeIds = Set(persisted.map(\.badgeId))
        refreshSnapshot()
    }

    // MARK: Public logging API — one purpose-named method per event source,
    // matching AppState's existing style (createNote, recordConceptView).

    func logConceptViewed(conceptId: UUID, conceptType: ConceptType) {
        recordEvent(.conceptViewed, conceptId: conceptId, conceptType: conceptType)
    }

    func logSearchPerformed() {
        recordEvent(.searchPerformed)
    }

    func logNoteCaptured() {
        recordEvent(.noteCaptured)
    }

    func logChartLookupSessionCompleted() {
        recordEvent(.chartLookupSessionCompleted)
    }

    func logAppForegrounded() {
        recordEvent(.appForegrounded)
    }

    func logAppBackgrounded() {
        recordEvent(.appBackgrounded)
    }

    /// Called by AppState on launch and whenever onboarding/profile edits
    /// change the nurse's chosen specialties — the Specialist badge scores
    /// against whichever specialties are current, not just the ones chosen
    /// at first launch.
    func updateSpecialties(_ specialties: Set<Specialty>) {
        self.specialties = specialties
        refreshSnapshot()
    }

    /// Counts and active-usage minutes over a trailing window — same event
    /// log as `snapshot`, just date-scoped and summed rather than reduced to
    /// distinct-concept sets. Pure presentation over the same source of
    /// truth (see GAMIFICATION_ADR.md "Usage summary").
    func usageSummary(for period: SummaryPeriod) -> UsageSummary {
        let since = Calendar.current.date(byAdding: .day, value: -period.trailingDays, to: Date()) ?? .distantPast
        let events = ((try? modelContext.fetch(FetchDescriptor<GamificationEvent>())) ?? [])
            .filter { $0.at >= since }
            .sorted { $0.at < $1.at }

        var summary = UsageSummary()
        var openForegroundedAt: Date?
        for event in events {
            switch event.type {
            case .conceptViewed: summary.conceptsViewed += 1
            case .searchPerformed: summary.searchesPerformed += 1
            case .noteCaptured: summary.notesCaptured += 1
            case .chartLookupSessionCompleted: summary.chartLookupSessions += 1
            case .appForegrounded: openForegroundedAt = event.at
            case .appBackgrounded:
                if let start = openForegroundedAt {
                    summary.activeMinutes += max(0, Int(event.at.timeIntervalSince(start) / 60))
                    openForegroundedAt = nil
                }
            }
        }
        // Still foregrounded right now (never backgrounded within this
        // window) — count up to the present moment instead of dropping it.
        if let openForegroundedAt {
            summary.activeMinutes += max(0, Int(Date().timeIntervalSince(openForegroundedAt) / 60))
        }
        return summary
    }

    /// Pops the currently-presented unlock so the next queued one (if any)
    /// shows next — badges/level-ups are shown one at a time.
    func dismissCurrentUnlock() {
        guard !unlockQueue.isEmpty else { return }
        unlockQueue.removeFirst()
    }

    // MARK: - Internals

    private func recordEvent(_ type: GamificationEventType, conceptId: UUID? = nil, conceptType: ConceptType? = nil) {
        modelContext.insert(GamificationEvent(type: type, conceptId: conceptId, conceptType: conceptType))
        try? modelContext.save()

        let events = (try? modelContext.fetch(FetchDescriptor<GamificationEvent>())) ?? []
        let baseSnapshot = computeBaseSnapshot(events: events)

        let newlyUnlocked = BadgeCatalog.all.filter { !unlockedBadgeIds.contains($0.id) && $0.isUnlocked(baseSnapshot) }
        if !newlyUnlocked.isEmpty {
            for badge in newlyUnlocked {
                modelContext.insert(UnlockedBadgeRecord(badgeId: badge.id))
                unlockedBadgeIds.insert(badge.id)
            }
            try? modelContext.save()
        }

        let previousLevel = level
        refreshSnapshot(baseSnapshot: baseSnapshot)

        for badge in newlyUnlocked { unlockQueue.append(.badge(badge)) }
        if level > previousLevel { unlockQueue.append(.levelUp(level)) }
    }

    private func refreshSnapshot(baseSnapshot: GamificationSnapshot? = nil) {
        var snap = baseSnapshot ?? computeBaseSnapshot(events: (try? modelContext.fetch(FetchDescriptor<GamificationEvent>())) ?? [])
        snap.totalPoints += unlockedBadgeIds.compactMap { BadgeCatalog.badge(id: $0)?.pointBonus }.reduce(0, +)
        snapshot = snap
        level = GamificationLevels.level(for: snap.totalPoints)
    }

    private func computeBaseSnapshot(events: [GamificationEvent]) -> GamificationSnapshot {
        var snap = GamificationSnapshot()
        var foregroundedDays: Set<DateComponents> = []
        let calendar = Calendar.current

        for event in events {
            switch event.type {
            case .conceptViewed:
                if let conceptId = event.conceptId, let conceptType = event.conceptType {
                    snap.distinctConceptsByType[conceptType, default: []].insert(conceptId)
                }
                snap.totalPoints += GamificationPoints.conceptViewed
            case .searchPerformed:
                snap.searchesPerformed += 1
                snap.totalPoints += GamificationPoints.searchPerformed
            case .noteCaptured:
                snap.notesCaptured += 1
                snap.totalPoints += GamificationPoints.noteCaptured
            case .chartLookupSessionCompleted:
                snap.chartLookupSessions += 1
                snap.totalPoints += GamificationPoints.chartLookupSessionCompleted
            case .appForegrounded:
                snap.appForegroundedCount += 1
                let day = calendar.dateComponents([.year, .month, .day], from: event.at)
                if !foregroundedDays.contains(day) {
                    foregroundedDays.insert(day)
                    snap.totalPoints += GamificationPoints.appForegroundedFirstOfDay
                }
            case .appBackgrounded:
                break
            }
        }

        snap.specialistCoverageFraction = specialistCoverageFraction(distinctConceptsByType: snap.distinctConceptsByType)
        return snap
    }

    /// Fraction of the corpus's specialty-tagged concepts the nurse has
    /// viewed, scoped to whichever specialties they chose in onboarding. 0 if
    /// they haven't chosen any, or none of their specialties tag any concepts.
    private func specialistCoverageFraction(distinctConceptsByType: [ConceptType: Set<UUID>]) -> Double {
        let specialtyTags = Set(specialties.map(\.rawValue))
        guard !specialtyTags.isEmpty else { return 0 }

        let taggedConcepts = library.concepts.filter { !Set($0.tags).isDisjoint(with: specialtyTags) }
        guard !taggedConcepts.isEmpty else { return 0 }

        let viewedIds = Set(distinctConceptsByType.values.flatMap { $0 })
        let viewedTaggedCount = taggedConcepts.filter { viewedIds.contains($0.id) }.count
        return Double(viewedTaggedCount) / Double(taggedConcepts.count)
    }
}
