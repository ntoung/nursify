import Foundation
import SwiftUI

/// In-memory stand-in for the real client architecture in SYSTEM_DESIGN.md
/// (local SQLDelight store + backend sync). Every view reads/writes through
/// this single environment object so the persistence layer can be swapped
/// out later without touching UI code.
@MainActor
final class AppState: ObservableObject {
    @Published var hasCompletedOnboarding = false
    @Published var userProfile = UserProfile(specialties: [], experienceLevel: nil)
    @Published var concepts: [Concept] = MockData.concepts
    @Published var notes: [Note] = MockData.notes
    @Published var suggestions: [Suggestion] = MockData.suggestions
    @Published var searchHistory: [SearchHistoryEntry] = MockData.searchHistory
    @Published var lookupSessions: [LookupSession] = MockData.lookupSessions

    /// Placeholder for the suggestion engine's streak stat — real value would
    /// come from ReviewSchedule state (see SYSTEM_DESIGN.md).
    let streakDays = 4

    func completeOnboarding(specialties: Set<Specialty>, experience: ExperienceLevel?) {
        userProfile = UserProfile(specialties: specialties, experienceLevel: experience)
        hasCompletedOnboarding = true
    }

    func concept(id: UUID) -> Concept? {
        concepts.first { $0.id == id }
    }

    /// Records a resolved concept view — logs the concept itself, not the raw
    /// query string, per the Learn page design in REQUIREMENTS.md.
    func recordSearchHistory(for concept: Concept) {
        searchHistory.removeAll { $0.conceptID == concept.id }
        let entry = SearchHistoryEntry(id: UUID(), conceptID: concept.id, conceptName: concept.name, type: concept.type, viewedAt: Date())
        searchHistory.insert(entry, at: 0)
    }

    func clearSearchHistory() {
        searchHistory.removeAll()
    }

    /// LookupSessions are shift-scoped and, per SYSTEM_DESIGN.md, never touch
    /// a backend — this in-memory array is the entire lifecycle for now.
    func addLookupSession(_ session: LookupSession) {
        lookupSessions.insert(session, at: 0)
    }

    func clearLookupHistory() {
        lookupSessions.removeAll()
    }

    func medicationExplanation(for name: String, complaints: [String]) -> MedicationExplanation {
        if let concept = concepts.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            return MedicationExplanation(
                id: UUID(),
                name: concept.name,
                relatedComplaints: complaints,
                shortExplanation: concept.shortExplanation,
                longExplanation: concept.sections.mechanism
            )
        }
        return MedicationExplanation(
            id: UUID(),
            name: name,
            relatedComplaints: complaints,
            shortExplanation: "Explanation not yet available for \(name) — this concept hasn't been curated yet.",
            longExplanation: nil
        )
    }
}
