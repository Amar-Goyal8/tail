import Foundation
import AVFoundation
import AppKit

// Uploads a saved clip and returns a share link.
// Flow (matches web/app/api): POST /api/upload -> presigned PUT -> PUT mp4 to R2
// -> POST /api/finalize -> share link.
final class Uploader: @unchecked Sendable {
    private let baseURL: URL

    init(baseURL: URL) { self.baseURL = baseURL }

    struct UploadInit: Decodable { let id: String; let uploadUrl: String; let videoUrl: String }
    struct Finalized: Decodable { let id: String; let link: String }

    func upload(_ file: URL, game: String? = nil) async throws -> String {
        guard let token = await AuthManager.shared.accessToken else {
            throw NSError(domain: "tail.upload", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "Sign in to share clips"])
        }
        // 1. Ask backend for an id + presigned PUT URL.
        var initReq = URLRequest(url: baseURL.appendingPathComponent("api/upload"))
        initReq.httpMethod = "POST"
        initReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        initReq.httpBody = try JSONSerialization.data(withJSONObject: ["contentType": "video/mp4"])
        let (initData, initResp) = try await URLSession.shared.data(for: initReq)
        try Self.check(initResp, initData)
        let info = try JSONDecoder().decode(UploadInit.self, from: initData)

        // 2. PUT the mp4 straight to R2.
        var putReq = URLRequest(url: URL(string: info.uploadUrl)!)
        putReq.httpMethod = "PUT"
        putReq.setValue("video/mp4", forHTTPHeaderField: "Content-Type")
        let (putData, putResp) = try await URLSession.shared.upload(for: putReq, fromFile: file)
        try Self.check(putResp, putData)

        // 3. Finalize with metadata (dimensions + duration read from the file).
        let (w, h, dur) = await Self.dimensions(of: file)
        var finReq = URLRequest(url: baseURL.appendingPathComponent("api/finalize"))
        finReq.httpMethod = "POST"
        finReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        finReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        var meta: [String: Any] = ["id": info.id, "width": w, "height": h, "durationSec": dur]
        if let game { meta["game"] = game }
        finReq.httpBody = try JSONSerialization.data(withJSONObject: meta)
        let (finData, finResp) = try await URLSession.shared.data(for: finReq)
        try Self.check(finResp, finData)
        let done = try JSONDecoder().decode(Finalized.self, from: finData)
        return done.link
    }

    private static func check(_ resp: URLResponse, _ data: Data) throws {
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "tail.upload", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "HTTP error: \(body)"])
        }
    }

    private static func dimensions(of file: URL) async -> (Int, Int, Double) {
        let asset = AVURLAsset(url: file)
        let dur = (try? await asset.load(.duration))?.seconds ?? 0
        guard let track = try? await asset.loadTracks(withMediaType: .video).first,
              let size = try? await track.load(.naturalSize) else { return (0, 0, dur) }
        return (Int(abs(size.width)), Int(abs(size.height)), dur)
    }
}
