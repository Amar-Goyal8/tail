import Foundation
import AVFoundation
import AppKit

// A locally-saved clip. Share link is created on demand (not automatically).
struct LocalClip: Codable, Identifiable, Sendable {
    let filename: String
    let createdAt: Date
    var link: String?
    var game: String?          // capture source (window/app title)
    var desc: String?          // user description
    var views: Int?            // fetched from backend when shared
    var folder: String?        // organizing folder (nil = unsorted)
    var id: String { filename }
}

// Tracks clips saved to disk + their (optional) share links. Persists an index
// so clips show up immediately without re-uploading. Generates thumbnails.
@MainActor
final class LocalLibrary: ObservableObject {
    @Published private(set) var clips: [LocalClip] = []
    @Published private(set) var folders: [String] = []
    private let dir: URL
    private var indexURL: URL { dir.appendingPathComponent(".tail-clips.json") }
    private var foldersURL: URL { dir.appendingPathComponent(".tail-folders.json") }
    private var thumbs: [String: NSImage] = [:]

    init(dir: URL) {
        self.dir = dir
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        load()
    }

    // MARK: Folders
    func clips(in folder: String?) -> [LocalClip] {
        folder == nil ? clips : clips.filter { $0.folder == folder }
    }

    func createFolder(_ name: String) {
        let n = name.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty, !folders.contains(n) else { return }
        folders.append(n); folders.sort(); persistFolders()
    }

    func deleteFolder(_ name: String) {
        folders.removeAll { $0 == name }
        for i in clips.indices where clips[i].folder == name { clips[i].folder = nil }
        persistFolders(); persist()
    }

    func move(_ id: String, to folder: String?) {
        guard let i = clips.firstIndex(where: { $0.id == id }) else { return }
        clips[i].folder = folder; persist()
    }

    func moveMany(_ ids: Set<String>, to folder: String?) {
        for i in clips.indices where ids.contains(clips[i].id) { clips[i].folder = folder }
        persist()
    }

    func deleteMany(_ ids: Set<String>) {
        for clip in clips where ids.contains(clip.id) {
            try? FileManager.default.removeItem(at: url(for: clip)); thumbs[clip.id] = nil
        }
        clips.removeAll { ids.contains($0.id) }
        persist()
    }

    func url(for clip: LocalClip) -> URL { dir.appendingPathComponent(clip.filename) }

    // Record a newly-saved clip (newest first).
    func add(_ fileURL: URL, game: String? = nil) {
        let clip = LocalClip(filename: fileURL.lastPathComponent, createdAt: Date(),
                             link: nil, game: game, desc: nil, views: nil)
        clips.removeAll { $0.filename == clip.filename }
        clips.insert(clip, at: 0)
        persist()
    }

    func setLink(_ id: String, _ link: String) {
        guard let i = clips.firstIndex(where: { $0.id == id }) else { return }
        clips[i].link = link
        persist()
    }

    func setDescription(_ id: String, _ text: String) {
        guard let i = clips.firstIndex(where: { $0.id == id }) else { return }
        clips[i].desc = text
        persist()
    }

    func setViews(_ id: String, _ n: Int) {
        guard let i = clips.firstIndex(where: { $0.id == id }) else { return }
        clips[i].views = n
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
        if let data = try? Data(contentsOf: indexURL),
           let list = try? JSONDecoder().decode([LocalClip].self, from: data) {
            clips = list.filter { FileManager.default.fileExists(atPath: dir.appendingPathComponent($0.filename).path) }
        }
        if let data = try? Data(contentsOf: foldersURL),
           let f = try? JSONDecoder().decode([String].self, from: data) {
            folders = f
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(clips) { try? data.write(to: indexURL) }
    }
    private func persistFolders() {
        if let data = try? JSONEncoder().encode(folders) { try? data.write(to: foldersURL) }
    }
}
