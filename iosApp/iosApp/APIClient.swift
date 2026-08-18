import Foundation

/// Talks directly to `backend/` over HTTP (URLSession + Codable) — not
/// through the `shared` KMP module. `shared/ApiClient.kt` already implements
/// this exact surface, but actually consuming it from iOS means building it
/// as an .xcframework in Xcode, which needs macOS. This is the pragmatic,
/// verifiable-by-review interim: same endpoints, native Swift.
///
/// Base URL is configurable (see `resolveBaseURL`) rather than hardcoded, so
/// the same binary can point at a dev machine, staging, or production without
/// code edits. `project.yml` carries the matching `NSAllowsLocalNetworking`
/// ATS exception for plaintext HTTP to a LAN dev backend.
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
    static let shared = APIClient(baseURL: APIClient.resolveBaseURL())

    /// Resolves the backend base URL, most-specific first:
    ///  1. A runtime override in UserDefaults under `APIBaseURL` — also settable
    ///     without a rebuild via an Xcode scheme launch arg or
    ///     `simctl launch … -APIBaseURL http://host:port` (great for QA).
    ///  2. The build-time `APIBaseURL` value from Info.plist, set per
    ///     configuration in `project.yml` (dev vs. staging vs. production).
    ///  3. A hardcoded LAN default for a fresh dev checkout.
    static func resolveBaseURL() -> URL {
        if let override = UserDefaults.standard.string(forKey: "APIBaseURL"),
           let url = URL(string: override.trimmingCharacters(in: .whitespaces)), url.scheme != nil {
            return url
        }
        if let configured = Bundle.main.object(forInfoDictionaryKey: "APIBaseURL") as? String,
           let url = URL(string: configured.trimmingCharacters(in: .whitespaces)), url.scheme != nil {
            return url
        }
        return URL(string: "http://192.168.1.194:8081")!
    }

    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(baseURL: URL, session: URLSession? = nil) {
        self.baseURL = baseURL
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 15
            config.waitsForConnectivity = false
            self.session = URLSession(configuration: config)
        }

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

    /// The full corpus with complete detail in a single request — used by
    /// ConceptLibrary to refresh its offline snapshot when the backend is
    /// reachable, rather than issuing per-category + per-id calls.
    func allConcepts() async throws -> [Concept] {
        try await get(baseURL.appendingPathComponent("concepts"))
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

    // MARK: - Notes (keyword-matched concept mentions; see backend
    // ConceptRepository.findMentions for why this isn't real LLM extraction)

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
        let mentionedConcepts: [MentionedConcept]
    }

    func createNote(transcript: String, device: CaptureDevice, phiReviewed: Bool) async throws -> NoteResponseBody {
        let body = NoteCreateBody(transcript: transcript, device: device.rawValue, phiReviewed: phiReviewed)
        return try await post(baseURL.appendingPathComponent("notes"), body: body)
    }

    // MARK: - Suggestions

    func suggestions(specialty: String? = nil) async throws -> [Suggestion] {
        var components = URLComponents(url: baseURL.appendingPathComponent("suggestions"), resolvingAgainstBaseURL: false)!
        if let specialty {
            components.queryItems = [URLQueryItem(name: "specialty", value: specialty)]
        }
        return try await get(components.url!)
    }

    // MARK: - Problem reports (shake-to-report)

    private struct ReportCreateBody: Encodable {
        let message: String
        let context: String?
    }

    struct ReportResponse: Decodable {
        let id: UUID
        let message: String
        let createdAt: Date
    }

    @discardableResult
    func submitReport(message: String, context: String? = nil) async throws -> ReportResponse {
        try await post(baseURL.appendingPathComponent("reports"), body: ReportCreateBody(message: message, context: context))
    }

    // MARK: - Low-level helpers

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
