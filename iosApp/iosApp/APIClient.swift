import Foundation

/// Talks directly to `backend/` over HTTP (URLSession + Codable) — not
/// through the `shared` KMP module. `shared/ApiClient.kt` already implements
/// this exact surface, but actually consuming it from iOS means building it
/// as an .xcframework in Xcode, which needs macOS. This is the pragmatic,
/// verifiable-by-review interim: same endpoints, native Swift.
///
/// Base URL points at the Mac's LAN IP so both the Simulator and a physical
/// device on the same Wi-Fi network can reach the backend. `project.yml`
/// carries the matching `NSAllowsLocalNetworking` ATS exception. If the
/// Mac's IP changes (new network, DHCP renewal), update this and re-run
/// `xcodegen generate`.
enum APIError: Error, LocalizedError {
    case invalidResponse
    case server(status: Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "The server sent back something unexpected."
        case .server(let status): return "Server returned status \(status)."
        }
    }
}

final class APIClient {
    static let shared = APIClient(baseURL: URL(string: "http://192.168.1.194:8081")!)

    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        self.encoder = encoder
    }

    // MARK: - Concepts

    func searchConcepts(query: String) async throws -> [ConceptSummary] {
        var components = URLComponents(url: baseURL.appendingPathComponent("concepts/search"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        return try await get(components.url!)
    }

    func conceptsByCategory(_ type: ConceptType) async throws -> [ConceptSummary] {
        try await get(baseURL.appendingPathComponent("concepts/category/\(type.rawValue.lowercased())"))
    }

    func concept(id: UUID) async throws -> Concept {
        try await get(baseURL.appendingPathComponent("concepts/\(id.uuidString)"))
    }

    // MARK: - Chart lookup (stateless — nothing persisted server-side)

    struct ChartLookupRequestBody: Encodable {
        let chiefComplaints: [String]
        let medicationNames: [String]
    }

    struct ChartLookupResponseBody: Decodable {
        let chiefComplaints: [String]
        let medications: [MedicationExplanation]
    }

    func chartLookup(chiefComplaints: [String], medicationNames: [String]) async throws -> ChartLookupResponseBody {
        let body = ChartLookupRequestBody(chiefComplaints: chiefComplaints, medicationNames: medicationNames)
        return try await post(baseURL.appendingPathComponent("chart-lookup"), body: body)
    }

    // MARK: - Notes (persist-only — no AI augmentation pipeline yet)

    struct NoteCreateBody: Encodable {
        let transcript: String
        let device: String
        let phiReviewed: Bool
    }

    struct NoteResponseBody: Decodable {
        let id: UUID
        let transcript: String
        let device: String
        let phiReviewed: Bool
        let createdAt: Date
    }

    func createNote(transcript: String, device: CaptureDevice, phiReviewed: Bool) async throws -> NoteResponseBody {
        let body = NoteCreateBody(transcript: transcript, device: device.rawValue, phiReviewed: phiReviewed)
        return try await post(baseURL.appendingPathComponent("notes"), body: body)
    }

    // MARK: - Suggestions

    func suggestions() async throws -> [Suggestion] {
        try await get(baseURL.appendingPathComponent("suggestions"))
    }

    // MARK: - Search history (synced — general medical-knowledge browsing,
    // not patient-encounter data, so unlike chart lookup this is fine to sync)

    func searchHistory() async throws -> [SearchHistoryEntry] {
        try await get(baseURL.appendingPathComponent("search-history"))
    }

    @discardableResult
    func recordSearchHistory(conceptId: UUID) async throws -> SearchHistoryEntry {
        try await post(baseURL.appendingPathComponent("search-history/\(conceptId.uuidString)"), body: EmptyBody())
    }

    func clearSearchHistory() async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("search-history"))
        request.httpMethod = "DELETE"
        let (_, response) = try await session.data(for: request)
        try validate(response)
    }

    // MARK: - Low-level helpers

    private struct EmptyBody: Encodable {}

    private func get<T: Decodable>(_ url: URL) async throws -> T {
        let (data, response) = try await session.data(from: url)
        try validate(response)
        return try decoder.decode(T.self, from: data)
    }

    private func post<Body: Encodable, T: Decodable>(_ url: URL, body: Body) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        let (data, response) = try await session.data(for: request)
        try validate(response)
        return try decoder.decode(T.self, from: data)
    }

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw APIError.server(status: http.statusCode) }
    }
}
