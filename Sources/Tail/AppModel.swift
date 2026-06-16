import AppKit
import SwiftUI

// Shared state + actions between the menu bar and the main window.
@MainActor
final class AppModel: ObservableObject {
    @Published var plan = "free"
    @Published var presetName = Config.presets.first!.name
    @Published var sourceLabel = "Main display"
    @Published var uploadOnClip = true
    @Published var micEnabled = false
    @Published var lastLink: String?
    @Published var statusText = "Ready"
    @Published var clipsRefreshToken = 0

    // Wired by AppDelegate.
    var onClip: () -> Void = {}
    var onTrimLast: () -> Void = {}
    var onPickPreset: (String) -> Void = { _ in }
    var onToggleUpload: (Bool) -> Void = { _ in }
    var onToggleMic: (Bool) -> Void = { _ in }
    var onUpgrade: () -> Void = {}
    var onOpenClipsFolder: () -> Void = {}
    var clipsClient: ClipsClient?

    // Local library + on-demand share-link creation.
    var library: LocalLibrary!
    var uploader: Uploader?

    // Upload the clip + create its share link (returns nil on failure).
    func createLink(for clip: LocalClip) async -> String? {
        guard let uploader, let library else { return nil }
        let fileURL = library.url(for: clip)
        guard let link = try? await uploader.upload(fileURL) else { return nil }
        library.setLink(clip.id, link)
        return link
    }
}
