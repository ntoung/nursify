import Combine
import Foundation

/// The watch's local list of recent captures - the on-watch "record" the nurse
/// sees. A row is added the moment recording stops (so there's immediate
/// confirmation something happened), then updated in place when the phone
/// reports back what it did with the clip. Persisted so the list survives
/// relaunch; capped to the most recent few.
@MainActor
final class WatchCaptureStore: ObservableObject {
    static let shared = WatchCaptureStore()

    @Published private(set) var records: [WatchCaptureRecord] = []

    private let maxRecords = 25
    private let fileURL: URL? = {
        try? FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("WatchCaptures.json")
    }()

    init() { load() }

    /// Adds a "sending" row for a just-finished recording and returns its id,
    /// which is sent to the phone so its result can be matched back to this row.
    func addSending() -> UUID {
        let record = WatchCaptureRecord(
            id: UUID(),
            createdAt: Date(),
            status: .sending,
            kind: .pending,
            title: "Sending…",
            detail: "",
            phiFlagged: false
        )
        records.insert(record, at: 0)
        trimAndPersist()
        return record.id
    }

    /// Applies the phone's result to the matching row (ignored if that row has
    /// aged out of the capped list).
    func apply(_ result: WatchCaptureResult) {
        guard let id = UUID(uuidString: result.captureId),
              let index = records.firstIndex(where: { $0.id == id }) else { return }
        records[index].status = result.kind == .failed ? .failed : .done
        records[index].kind = {
            switch result.kind {
            case .note: return .note
            case .definition: return .definition
            case .failed: return .pending
            }
        }()
        records[index].title = result.title
        records[index].detail = result.detail
        records[index].phiFlagged = result.phiFlagged
        trimAndPersist()
    }

    private func trimAndPersist() {
        if records.count > maxRecords {
            records = Array(records.prefix(maxRecords))
        }
        guard let fileURL, let data = try? JSONEncoder().encode(records) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private func load() {
        guard let fileURL, let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([WatchCaptureRecord].self, from: data) else { return }
        records = decoded
    }
}
