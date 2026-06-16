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

    var bitrate: Int { bitrateMbps * 1_000_000 }

    // Preset toggle: 1440p120 (quality) vs 1080p240 (smoothness).
    static let p1440_120 = Config(width: 2560, height: 1440, fps: 120, bitrateMbps: 50)
    static let p1080_240 = Config(width: 1920, height: 1080, fps: 240, bitrateMbps: 40)
}
