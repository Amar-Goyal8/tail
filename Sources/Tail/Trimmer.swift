import Foundation
import AVFoundation

// Cut a clip to [start, end] seconds. Passthrough export = fast, no re-encode
// (cuts to the nearest keyframe; we key every 1s so that's tight). Keeps audio.
enum Trimmer {
    static func trim(_ src: URL, start: Double, end: Double) async throws -> URL {
        let asset = AVURLAsset(url: src)
        let dur = (try? await asset.load(.duration))?.seconds ?? 0
        let s = max(0, min(start, dur))
        let e = max(s + 0.1, min(end, dur))

        guard let export = AVAssetExportSession(asset: asset,
                                                presetName: AVAssetExportPresetPassthrough) else {
            throw NSError(domain: "tail.trim", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "no export session"])
        }
        let out = src.deletingPathExtension().appendingPathExtension("trim.mp4")
        try? FileManager.default.removeItem(at: out)
        export.outputURL = out
        export.outputFileType = .mp4
        let scale: Int32 = 600
        export.timeRange = CMTimeRange(
            start: CMTime(seconds: s, preferredTimescale: scale),
            end: CMTime(seconds: e, preferredTimescale: scale))

        await export.export()
        guard export.status == .completed else {
            throw export.error ?? NSError(domain: "tail.trim", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "export failed (\(export.status.rawValue))"])
        }
        return out
    }
}
