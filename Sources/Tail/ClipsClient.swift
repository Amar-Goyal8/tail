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

    private struct AccountResp: Decodable { let plan: String }
    func plan() async throws -> String {
        var req = URLRequest(url: baseURL.appendingPathComponent("api/account"))
        req.setValue("Bearer \(Account.token)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        try Self.check(resp, data)
        return try JSONDecoder().decode(AccountResp.self, from: data).plan
    }

    private struct CheckoutResp: Decodable { let url: String? }
    // Returns a Stripe Checkout URL, or nil if billing not configured.
    func checkoutURL() async throws -> String? {
        var req = URLRequest(url: baseURL.appendingPathComponent("api/checkout"))
        req.httpMethod = "POST"
        req.setValue("Bearer \(Account.token)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { return nil }
        if http.statusCode == 503 { return nil } // billing not configured yet
        try Self.check(resp, data)
        return try JSONDecoder().decode(CheckoutResp.self, from: data).url
    }

    private struct StatsResp: Decodable { let views: Int }
    func views(id: String) async throws -> Int {
        let req = URLRequest(url: baseURL.appendingPathComponent("api/clip/\(id)"))
        let (data, resp) = try await URLSession.shared.data(for: req)
        try Self.check(resp, data)
        return try JSONDecoder().decode(StatsResp.self, from: data).views
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
