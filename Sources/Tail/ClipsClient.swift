import Foundation

// Talks to the backend's account-scoped clip API ("my clips").
struct ClipSummary: Decodable, Identifiable, Sendable {
    let id: String
    let title: String?
    let width: Int
    let height: Int
    let durationSec: Double
    let createdAt: String
    let link: String
    let videoUrl: String
}

final class ClipsClient: @unchecked Sendable {
    private let baseURL: URL
    init(baseURL: URL) { self.baseURL = baseURL }

    private struct ListResponse: Decodable { let clips: [ClipSummary] }

    func list() async throws -> [ClipSummary] {
        var req = URLRequest(url: baseURL.appendingPathComponent("api/clips"))
        req.setValue("Bearer \(Account.token)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        try Self.check(resp, data)
        return try JSONDecoder().decode(ListResponse.self, from: data).clips
    }

    func delete(_ id: String) async throws {
        var req = URLRequest(url: baseURL.appendingPathComponent("api/clips/\(id)"))
        req.httpMethod = "DELETE"
        req.setValue("Bearer \(Account.token)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        try Self.check(resp, data)
    }

    private static func check(_ resp: URLResponse, _ data: Data) throws {
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "tail.clips", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "HTTP \( (resp as? HTTPURLResponse)?.statusCode ?? -1)"])
        }
    }
}
