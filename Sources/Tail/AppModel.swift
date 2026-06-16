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

    // Wired by AppDelegate.
    var onClip: () -> Void = {}
    var onTrimLast: () -> Void = {}
    var onPickPreset: (String) -> Void = { _ in }
    var onToggleUpload: (Bool) -> Void = { _ in }
    var onToggleMic: (Bool) -> Void = { _ in }
    var onUpgrade: () -> Void = {}
    var onOpenClipsFolder: () -> Void = {}
    var clipsClient: ClipsClient?
}
