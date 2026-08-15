import Foundation
import SwiftUI
import Network

/// Client state, now backed by real network calls to `backend/` via
/// APIClient — see APIClient.swift for why this is native Swift rather than
/// going through `shared`. `notes` and `lookupSessions` are deliberately
/// still local-only: there's no GET /notes endpoint yet, and LookupSession
/// is client-local by design (REQUIREMENTS.md — no PHI ever leaves the device).
@MainActor
final class AppState: ObservableObject {
    @Published var hasCompletedOnboarding = false
    @Published var userProfile = UserProfile(name: "", specialties: [], experienceLevel: nil)

    @Published var notes: [Note] = []
    @Published var lookupSessions: [LookupSession] = SampleData.lookupSessions

    @Published var suggestions: [Suggestion] = []
    @Published var searchHistory: [SearchHistoryEntry] = []

    /// Local ids of notes captured offline and still awaiting sync — drives the
    /// "pending" indicator in the Journal list.
    @Published private(set) var pendingNoteIds: Set<UUID> = []

    @Published var errorMessage: String?

    /// Finished watch notes (WatchConnectivityReceiver) awaiting the same
    /// review/PHI-acknowledgment step as any other capture before they're
    /// saved — see REQUIREMENTS.md "queued and finished/transcribed on phone
    /// via Watch Connectivity." A FIFO queue rather than a single optional:
    /// a nurse can finish a second watch note before reviewing the first, and
    /// this way the second never silently overwrites/loses the first — each
    /// is reviewed in turn. JournalView pops the next one when it's ready.
    @Published var pendingWatchDrafts: [String] = []

    /// Removes and returns the oldest queued watch note, if any.
    func popNextPendingWatchDraft() -> String? {
        guard !pendingWatchDrafts.isEmpty else { return nil }
        return pendingWatchDrafts.removeFirst()
    }

    private let api: APIClient

    /// The concept corpus, served locally from the bundled snapshot so search,
    /// browsing, and detail work fully offline. See ConceptLibrary.
    let library: ConceptLibrary

    /// On-device badges/points/levels — see GAMIFICATION_ADR.md. Entirely
    /// local, never synced.
    let gamification: GamificationEngine

    /// Durable outbox of mutations made offline, replayed when the backend is
    /// reachable again. See SyncQueue and flushOutbox().
    private var syncQueue = SyncQueue()
    private var isFlushing = false

    /// Watches connectivity and flushes the outbox as soon as the network
    /// returns — this is what makes "sync later" automatic.
    private let pathMonitor = NWPathMonitor()

    private static let notesFileURL: URL? = {
        try? FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("Notes.json")
    }()

    /// Onboarding answers are device-local (no profile endpoint exists yet),
    /// persisted to UserDefaults so they survive relaunch instead of asking
    /// again every time the app opens.
    private enum StorageKey {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let userProfile = "userProfile"
    }

    init(api: APIClient = .shared, library: ConceptLibrary = .shared, gamification: GamificationEngine? = nil) {
        self.api = api
        self.library = library
        self.gamification = gamification ?? GamificationEngine(library: library)
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: StorageKey.hasCompletedOnboarding)
        if let data = UserDefaults.standard.data(forKey: StorageKey.userProfile),
           let profile = try? JSONDecoder().decode(UserProfile.self, from: data) {
            userProfile = profile
        }
        notes = AppState.loadNotes()
        pendingNoteIds = syncQueue.pendingNoteIds
        self.gamification.updateSpecialties(userProfile.specialties)
        startConnectivityMonitoring()
    }

    /// Refreshes the offline concept library from the backend when reachable.
    /// Safe to call on launch — it no-ops silently when offline, since the
    /// bundled snapshot already backs every concept read.
    func refreshLibrary() async {
        await library.refresh()
    }

    // MARK: - Offline outbox (see SyncQueue)

    private func startConnectivityMonitoring() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            Task { @MainActor in await self?.flushOutbox() }
        }
        pathMonitor.start(queue: DispatchQueue(label: "com.nursify.connectivity"))
    }

    /// Replays queued mutations in order, stopping at the first failure so the
    /// remaining operations stay queued for the next attempt (launch, a later
    /// action, or connectivity returning). Safe to call repeatedly.
    func flushOutbox() async {
        guard !isFlushing else { return }
        isFlushing = true
        defer { isFlushing = false }

        var syncedAnyView = false
        for op in syncQueue.operations {
            do {
                switch op.operation {
                case .createNote(let localId, let transcript, let device, let phiReviewed):
                    let captureDevice = CaptureDevice(rawValue: device) ?? .phone
                    let response = try await api.createNote(transcript: transcript, device: captureDevice, phiReviewed: phiReviewed)
                    reconcileNote(localId: localId, serverMentions: response.mentionedConcepts)
                case .recordView(let conceptId):
                    _ = try await api.recordSearchHistory(conceptId: conceptId)
                    syncedAnyView = true
                }
                syncQueue.remove(op.id)
                pendingNoteIds = syncQueue.pendingNoteIds
            } catch {
                // Offline or backend down — leave this and everything after it
                // queued, preserving order, and try again later.
                break
            }
        }

        if syncedAnyView { await loadSearchHistory() }
    }

    /// Merge the server's authoritative concept mentions onto the optimistic
    /// note once its creation syncs. Identity stays the local id (the client
    /// never needs the server's note id), so nothing in the UI reflows.
    private func reconcileNote(localId: UUID, serverMentions: [MentionedConcept]) {
        guard let index = notes.firstIndex(where: { $0.id == localId }) else { return }
        let existing = notes[index]
        notes[index] = Note(
            id: existing.id,
            transcript: existing.transcript,
            device: existing.device,
            phiFlagged: existing.phiFlagged,
            createdAt: existing.createdAt,
            mentionedConcepts: serverMentions.isEmpty ? existing.mentionedConcepts : serverMentions,
            entryGroupId: existing.entryGroupId
        )
        persistNotes()
    }

    private func persistNotes() {
        guard let url = AppState.notesFileURL, let data = try? JSONEncoder().encode(notes) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// Loads persisted notes. The list starts empty on a fresh install — the
    /// Journal tab shows an empty state until the user creates their own entry.
    private static func loadNotes() -> [Note] {
        guard let url = notesFileURL, FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let notes = try? JSONDecoder().decode([Note].self, from: data) else {
            return []
        }
        return notes
    }

    func completeOnboarding(name: String, specialties: Set<Specialty>, experience: ExperienceLevel?) {
        userProfile = UserProfile(name: name, specialties: specialties, experienceLevel: experience)
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: StorageKey.hasCompletedOnboarding)
        if let data = try? JSONEncoder().encode(userProfile) {
            UserDefaults.standard.set(data, forKey: StorageKey.userProfile)
        }
        gamification.updateSpecialties(specialties)
        // First real "session start" from a product standpoint — this is
        // what should trigger First Shift, not any foreground that happens
        // to occur mid-onboarding (ContentView suppresses those; see its
        // scenePhase handler).
        gamification.logAppForegrounded()
    }

    // MARK: - Network-backed loads

    // Suggestions and synced search history are online-only personalization
    // features (they live server-side). When offline they simply don't update —
    // failures are swallowed rather than surfaced, so the offline-first concept
    // experience stays clean instead of flashing network errors.
    func loadSuggestions() async {
        let specialty = userProfile.specialties.map(\.rawValue).sorted().first
        if let result = try? await api.suggestions(specialty: specialty) {
            suggestions = result
        }
    }

    func loadSearchHistory() async {
        if let result = try? await api.searchHistory() {
            searchHistory = result
        }
    }

    // Concept content is served from the offline library, so search, category
    // browsing, and detail all work with no network. The library refreshes from
    // the backend separately (see refreshLibrary()).
    func searchConcepts(query: String) async -> [ConceptSummary] {
        let results = library.search(query)
        gamification.logSearchPerformed()
        return results
    }

    func conceptsByCategory(_ type: ConceptType) async -> [ConceptSummary] {
        library.byCategory(type)
    }

    func fetchConcept(id: UUID) async throws -> Concept {
        if let local = library.concept(id: id) { return local }
        // Fallback for any id not in the bundled snapshot (shouldn't normally
        // happen, but keeps deep links / stale references working when online).
        return try await api.concept(id: id)
    }

    /// Records a resolved concept view. Queued through the outbox so a view
    /// registered offline still syncs later, rather than being dropped — search
    /// history is general medical-knowledge browsing (not patient data), so
    /// unlike chart-lookup history it's fine to sync.
    func recordSearchHistory(conceptId: UUID) async {
        if let conceptType = library.concept(id: conceptId)?.type {
            gamification.logConceptViewed(conceptId: conceptId, conceptType: conceptType)
        }
        syncQueue.enqueue(.recordView(conceptId: conceptId))
        await flushOutbox()
    }

    func clearSearchHistory() async {
        do {
            try await api.clearSearchHistory()
            searchHistory = []
        } catch {
            errorMessage = "Couldn't clear history: \(error.localizedDescription)"
        }
    }

    // MARK: - Chart lookup — computed entirely from the offline library, so it
    // works with no network and identically to the backend's stateless
    // /chart-lookup. The resulting LookupSession stays device-local (PHI never
    // leaves the device — see SYSTEM_DESIGN.md "Chart lookup (Feature B)").

    func performChartLookup(chiefComplaints: [String], medicationNames: [String], entryGroupId: UUID? = nil) -> LookupSession {
        let medications = library.chartLookup(chiefComplaints: chiefComplaints, medicationNames: medicationNames)
        let session = LookupSession(
            id: UUID(),
            chiefComplaints: chiefComplaints,
            medications: medications,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(60 * 60 * 24),
            entryGroupId: entryGroupId
        )
        lookupSessions.insert(session, at: 0)
        gamification.logChartLookupSessionCompleted()
        return session
    }

    func clearLookupHistory() {
        lookupSessions.removeAll()
    }

    func removeLookupSession(_ session: LookupSession) {
        lookupSessions.removeAll { $0.id == session.id }
    }

    /// Adds one more medication to an already-saved lookup session — the
    /// Journal entry detail view's "Add medication" affordance, for when a
    /// nurse thinks of another drug after the fact instead of redoing the
    /// whole entry.
    func addMedication(_ name: String, to session: LookupSession) {
        guard let index = lookupSessions.firstIndex(where: { $0.id == session.id }),
              let explanation = library.chartLookup(chiefComplaints: session.chiefComplaints, medicationNames: [name]).first
        else { return }
        lookupSessions[index].medications.append(explanation)
    }

    /// Removes a single medication from a session (swipe-to-remove on its
    /// row in the entry detail view) — distinct from removeLookupSession,
    /// which drops the whole session.
    func removeMedication(_ medication: MedicationExplanation, from session: LookupSession) {
        guard let index = lookupSessions.firstIndex(where: { $0.id == session.id }) else { return }
        lookupSessions[index].medications.removeAll { $0.id == medication.id }
    }

    /// Drops chart lookups past their 24-hour expiry, so the Journal list only
    /// ever shows the current window (see the "deleted after 24 hours" copy).
    func purgeExpiredLookups() {
        lookupSessions.removeAll { $0.expiresAt <= Date() }
    }

    // MARK: - Capture — offline-first via the outbox.
    //
    // A note is shown and persisted locally immediately (with concept mentions
    // computed on-device from the library), then queued for server sync. It
    // never depends on connectivity and never gets lost if the backend is
    // unreachable — see SyncQueue / flushOutbox.

    func createNote(transcript: String, device: CaptureDevice, phiReviewed: Bool, entryGroupId: UUID? = nil) async {
        let localId = UUID()
        let note = Note(
            id: localId,
            transcript: transcript,
            device: device,
            phiFlagged: false,
            createdAt: Date(),
            mentionedConcepts: library.mentions(in: transcript),
            entryGroupId: entryGroupId
        )
        notes.insert(note, at: 0)
        persistNotes()
        gamification.logNoteCaptured()

        syncQueue.enqueue(.createNote(localId: localId, transcript: transcript, device: device.rawValue, phiReviewed: phiReviewed))
        pendingNoteIds = syncQueue.pendingNoteIds

        await flushOutbox()
    }
}
