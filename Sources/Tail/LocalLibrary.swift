import Foundation
import AVFoundation
import AppKit

// A locally-saved clip. Share link is created on demand (not automatically).
struct LocalClip: Codable, Identifiable, Sendable {
    let filename: String
    let createdAt: Date
    var link: String?
    var id: String { filename }
}

// Tracks clips saved to disk + their (optional) share links. Persists an index
// so clips show up immediately without re-uploading. Generates thumbnails.
@MainActor
final class LocalLibrary: ObservableObject {
    @Published private(set) var clips: [LocalClip] = []
    private let dir: URL
    private var indexURL: URL { dir.appendingPathComponent(".tail-clips.json") }
    private var thumbs: [String: NSImage] = [:]

    init(dir: URL) {
        self.dir = dir
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        load()
    }

    func url(for clip: LocalClip) -> URL { dir.appendingPathComponent(clip.filename) }

    // Record a newly-saved clip (newest first).
    func add(_ fileURL: URL) {
        let clip = LocalClip(filename: fileURL.lastPathComponent, createdAt: Date(), link: nil)
        clips.removeAll { $0.filename == clip.filename }
        clips.insert(clip, at: 0)
        persist()
    }

    func setLink(_ id: String, _ link: String) {
        guard let i = clips.firstIndex(where: { $0.id == id }) else { return }
        clips[i].link = link
        persist()
    }

    func delete(_ clip: LocalClip) {
        try? FileManager.default.removeItem(at: url(for: clip))
        clips.removeAll { $0.id == clip.id }
        thumbs[clip.id] = nil
        persist()
    }

    // Cached thumbnail (first frame ~1s in).
    func thumbnail(for clip: LocalClip) async -> NSImage? {
        if let t = thumbs[clip.id] { return t }
        let asset = AVURLAsset(url: url(for: clip))
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 640, height: 360)
        let time = CMTime(seconds: 1, preferredTimescale: 600)
        guard let cg = try? await gen.image(at: time).image else { return nil }
        let img = NSImage(cgImage: cg, size: .zero)
        thumbs[clip.id] = img
        return img
    }

    private func load() {
        guard let data = try? Data(contentsOf: indexURL),
              let list = try? JSONDecoder().decode([LocalClip].self, from: data) else { return }
        // Keep only clips whose files still exist.
        clips = list.filter { FileManager.default.fileExists(atPath: dir.appendingPathComponent($0.filename).path) }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(clips) { try? data.write(to: indexURL) }
    }
}
