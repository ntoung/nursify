import Foundation
import SwiftUI

/// Client state, now backed by real network calls to `backend/` via
/// APIClient — see APIClient.swift for why this is native Swift rather than
/// going through `shared`. `notes` and `lookupSessions` are deliberately
/// still local-only: there's no GET /notes endpoint yet, and LookupSession
/// is client-local by design (REQUIREMENTS.md — no PHI ever leaves the device).
@MainActor
final class AppState: ObservableObject {
    @Published var hasCompletedOnboarding = false
    @Published var userProfile = UserProfile(name: "", specialties: [], experienceLevel: nil)

    @Published var notes: [Note] = MockData.notes
    @Published var lookupSessions: [LookupSession] = MockData.lookupSessions

    @Published var suggestions: [Suggestion] = []
    @Published var searchHistory: [SearchHistoryEntry] = []

    @Published var errorMessage: String?

    private let api: APIClient

    init(api: APIClient = .shared) {
        self.api = api
    }

    /// Placeholder for the suggestion engine's streak stat — real value would
    /// come from ReviewSchedule state (see SYSTEM_DESIGN.md).
    let streakDays = 4

    func completeOnboarding(name: String, specialties: Set<Specialty>, experience: ExperienceLevel?) {
        userProfile = UserProfile(name: name, specialties: specialties, experienceLevel: experience)
        hasCompletedOnboarding = true
    }

    // MARK: - Network-backed loads

    func loadSuggestions() async {
        do {
            suggestions = try await api.suggestions()
        } catch {
            errorMessage = "Couldn't load suggestions: \(error.localizedDescription)"
        }
    }

    func loadSearchHistory() async {
        do {
            searchHistory = try await api.searchHistory()
        } catch {
            errorMessage = "Couldn't load search history: \(error.localizedDescription)"
        }
    }

    func searchConcepts(query: String) async -> [ConceptSummary] {
        guard !query.isEmpty else { return [] }
        do {
            return try await api.searchConcepts(query: query)
        } catch {
            errorMessage = "Search failed: \(error.localizedDescription)"
            return []
        }
    }

    func conceptsByCategory(_ type: ConceptType) async -> [ConceptSummary] {
        do {
            return try await api.conceptsByCategory(type)
        } catch {
            errorMessage = "Couldn't load \(type.displayName): \(error.localizedDescription)"
            return []
        }
    }

    func fetchConcept(id: UUID) async throws -> Concept {
        try await api.concept(id: id)
    }

    /// Records a resolved concept view server-side, then refreshes the local
    /// list — search history is synced (general medical-knowledge browsing,
    /// not patient data), unlike chart-lookup history below.
    func recordSearchHistory(conceptId: UUID) async {
        do {
            _ = try await api.recordSearchHistory(conceptId: conceptId)
            await loadSearchHistory()
        } catch {
            errorMessage = "Couldn't record view: \(error.localizedDescription)"
        }
    }

    func clearSearchHistory() async {
        do {
            try await api.clearSearchHistory()
            searchHistory = []
        } catch {
            errorMessage = "Couldn't clear history: \(error.localizedDescription)"
        }
    }

    // MARK: - Chart lookup — network call, but the resulting LookupSession
    // stays local-only (see SYSTEM_DESIGN.md "Chart lookup (Feature B)").

    func performChartLookup(chiefComplaints: [String], medicationNames: [String]) async throws -> LookupSession {
        let response = try await api.chartLookup(chiefComplaints: chiefComplaints, medicationNames: medicationNames)
        let session = LookupSession(
            id: UUID(),
            chiefComplaints: response.chiefComplaints,
            medications: response.medications,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(60 * 60 * 24)
        )
        lookupSessions.insert(session, at: 0)
        return session
    }

    func clearLookupHistory() {
        lookupSessions.removeAll()
    }

    // MARK: - Capture — persists server-side; appended locally too since
    // there's no GET /notes endpoint yet to re-fetch the list from.

    func createNote(transcript: String, device: CaptureDevice, phiReviewed: Bool) async {
        do {
            let response = try await api.createNote(transcript: transcript, device: device, phiReviewed: phiReviewed)
            let note = Note(
                id: response.id,
                transcript: response.transcript,
                device: device,
                phiFlagged: false,
                createdAt: response.createdAt,
                mentionedConcepts: [] // no AI pipeline yet — honestly empty, not faked
            )
            notes.insert(note, at: 0)
        } catch {
            errorMessage = "Couldn't save note: \(error.localizedDescription)"
        }
    }
}
