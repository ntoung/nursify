import Foundation

/// One thing the nurse captured on the watch, shown in the capture list.
/// Created locally the instant recording stops (status `.sending`), then filled
/// in when the phone's WatchCaptureResult comes back over Watch Connectivity.
struct WatchCaptureRecord: Identifiable, Codable, Equatable {
    enum Status: String, Codable { case sending, done, failed }
    enum Kind: String, Codable { case pending, note, definition }

    let id: UUID
    var createdAt: Date
    var status: Status
    var kind: Kind
    /// Row headline: "Sending…", "Note saved", or the term name.
    var title: String
    /// Secondary text / detail-screen body: the note transcript or the definition.
    var detail: String
    var phiFlagged: Bool
}
