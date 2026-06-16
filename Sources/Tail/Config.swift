import Foundation

// Capture/encode settings. Free tier ceiling: 1440p120 / 1080p240.
struct Config {
    var width: Int = 2560
    var height: Int = 1440
    var fps: Int = 120
    var bitrateMbps: Int = 50
    var bufferSeconds: Int = 30
    var saveDir: URL = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first!
        .appendingPathComponent("Tail", isDirectory: true)

    // Audio (system audio capture).
    var audioSampleRate: Int = 48000
    var audioChannels: Int = 2
    var audioBitrate: Int = 160_000

    // Backend for upload + share links. Override with TAIL_BACKEND_URL env var
    // (e.g. http://localhost:3000 for dev, or the deployed Vercel URL).
    var backendURL: URL = URL(string: ProcessInfo.processInfo.environment["TAIL_BACKEND_URL"]
        ?? "https://web-tau-green-87.vercel.app")!
    var uploadOnClip: Bool = true
    var micEnabled: Bool = false
    var systemAudioEnabled: Bool = true
    var micDeviceUID: String? = nil   // selected input device (nil = system default)

    var bitrate: Int { bitrateMbps * 1_000_000 }

    // Quality presets. 4K is Pro-only (gated by account plan).
    static let p1440_120 = Config(width: 2560, height: 1440, fps: 120, bitrateMbps: 50)
    static let p1080_240 = Config(width: 1920, height: 1080, fps: 240, bitrateMbps: 40)
    static let p2160_60  = Config(width: 3840, height: 2160, fps: 60,  bitrateMbps: 90)

    struct Preset { let name: String; let config: Config; let pro: Bool }
    static let presets: [Preset] = [
        Preset(name: "1440p · 120fps", config: .p1440_120, pro: false),
        Preset(name: "1080p · 240fps", config: .p1080_240, pro: false),
        Preset(name: "4K · 60fps (Pro)", config: .p2160_60, pro: true),
    ]
}
