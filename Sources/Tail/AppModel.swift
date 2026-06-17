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
    @Published var showSettings = false

    // Foreground game (detected) + capture settings shown in the top bar.
    @Published var gameName = "Waiting for game…"
    @Published var gameIcon: NSImage?
    @Published var gameActive = false
    @Published var bufferSeconds = 30
    @Published var hotkeyLabel = "⌃⌥C"
    @Published var systemAudio = true
    @Published var micAudio = false
    @Published var inputDevices: [AudioDev] = []
    @Published var outputDevices: [AudioDev] = []
    @Published var selectedInput: String?   // mic uniqueID (nil = default)
    @Published var selectedOutput: String?  // output UID (system default)

    // Wired by AppDelegate.
    var onSetBuffer: (Int) -> Void = { _ in }
    var onSetSystemAudio: (Bool) -> Void = { _ in }
    var onOpenSettings: () -> Void = {}
    var onSetHotkey: (UInt32, UInt32, String) -> Void = { _, _, _ in } // keyCode, carbonMods, label
    var onSetInput: (String?) -> Void = { _ in }
    var onSetOutput: (String) -> Void = { _ in }

    func refreshDevices() {
        inputDevices = AudioDevices.inputs()
        outputDevices = AudioDevices.outputs()
        if selectedOutput == nil { selectedOutput = AudioDevices.defaultOutputUID() }
    }

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
        guard let link = try? await uploader.upload(fileURL, game: clip.game) else { return nil }
        library.setLink(clip.id, link)
        return link
    }

    // Pull the latest view count for a shared clip.
    func refreshViews(for clip: LocalClip) async {
        guard let clipsClient, let link = clip.link,
              let id = link.split(separator: "/").last.map(String.init) else { return }
        if let v = try? await clipsClient.views(id: id) { library?.setViews(clip.id, v) }
    }
}
