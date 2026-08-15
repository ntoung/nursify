import Foundation

/// A durable, replayable **outbox** for mutating API calls.
///
/// When the user acts while offline (or the backend is unreachable), the
/// mutation is applied optimistically to local state *and* appended here,
/// persisted to disk. AppState replays the queue — in order — whenever
/// connectivity returns (see `AppState.flushOutbox`), removing each operation
/// once the server confirms it. This is why a note captured on a dead hospital
/// Wi-Fi isn't lost: it's queued and synced later.
///
/// The queue is intentionally a plain value type with its own JSON persistence;
/// orchestration (optimistic UI, reconciliation, retries) lives in AppState.
struct SyncQueue {
    /// A mutating call that must eventually reach the backend. Extend this as
    /// new write endpoints appear — the replay machinery is operation-agnostic.
    enum Operation: Codable, Equatable {
        /// Create a capture note. `localId` is the id of the optimistic note
        /// already shown in the UI, so the server response can be reconciled
        /// back onto it.
        case createNote(localId: UUID, transcript: String, device: String, phiReviewed: Bool)
    }

    struct PendingOperation: Codable, Identifiable, Equatable {
        let id: UUID
        let operation: Operation
        let queuedAt: Date
    }

    private(set) var operations: [PendingOperation]

    private static let fileURL: URL? = {
        try? FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("SyncQueue.json")
    }()

    init() {
        operations = SyncQueue.load()
    }

    /// Local ids of notes still awaiting sync — drives the "pending" badge.
    var pendingNoteIds: Set<UUID> {
        Set(operations.compactMap {
            if case .createNote(let localId, _, _, _) = $0.operation { return localId }
            return nil
        })
    }

    mutating func enqueue(_ operation: Operation) {
        operations.append(PendingOperation(id: UUID(), operation: operation, queuedAt: Date()))
        persist()
    }

    mutating func remove(_ id: UUID) {
        operations.removeAll { $0.id == id }
        persist()
    }

    // MARK: - Persistence

    private func persist() {
        guard let url = SyncQueue.fileURL, let data = try? JSONEncoder().encode(operations) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private static func load() -> [PendingOperation] {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url),
              let ops = try? JSONDecoder().decode([PendingOperation].self, from: data) else { return [] }
        return ops
    }
}
