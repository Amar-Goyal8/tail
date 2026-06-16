import Foundation
import ScreenCaptureKit
import CoreMedia

// ScreenCaptureKit capture -> CFR clock -> Encoder.
// SCK is variable-rate (emits only on screen change). We hold the latest frame
// and a fixed-rate timer re-emits it every 1/fps onto a uniform PTS grid.
// Result: constant frame rate, uniform stts -> QuickTime paces correctly
// (it mis-guesses the rate of variable-rate HEVC otherwise).
// MVP: captures main display. Phase 1.2 will add per-window picker.
final class CaptureEngine: NSObject, SCStreamOutput, @unchecked Sendable {
    private let config: Config
    private let encoder: Encoder
    private var stream: SCStream?
    private let sampleQueue = DispatchQueue(label: "tail.capture")

    // Latest frame from SCK, guarded by lock. Clock pulls from here.
    private let frameLock = NSLock()
    private var latestFrame: CVPixelBuffer?

    private var clock: DispatchSourceTimer?
    private var frameIndex: Int64 = 0
    private let clockQueue = DispatchQueue(label: "tail.cfrclock")

    init(config: Config, encoder: Encoder) {
        self.config = config
        self.encoder = encoder
    }

    func start() async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false,
                                                                           onScreenWindowsOnly: true)
        guard let display = content.displays.first else {
            throw NSError(domain: "tail", code: 1, userInfo: [NSLocalizedDescriptionKey: "no display"])
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let cfg = SCStreamConfiguration()
        cfg.width = config.width
        cfg.height = config.height
        cfg.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(config.fps))
        cfg.pixelFormat = kCVPixelFormatType_32BGRA
        cfg.queueDepth = 8
        cfg.showsCursor = true

        let stream = SCStream(filter: filter, configuration: cfg, delegate: nil)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: sampleQueue)
        try await stream.startCapture()
        self.stream = stream
        startClock()
        FileHandle.standardError.write("capture started \(config.width)x\(config.height)@\(config.fps) (CFR)\n".data(using: .utf8)!)
    }

    // Fixed-rate clock: emit latest frame on a uniform PTS grid.
    private func startClock() {
        let interval = 1.0 / Double(config.fps)
        let timer = DispatchSource.makeTimerSource(queue: clockQueue)
        timer.schedule(deadline: .now() + interval, repeating: interval, leeway: .nanoseconds(0))
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            self.frameLock.lock()
            let frame = self.latestFrame
            self.frameLock.unlock()
            guard let frame else { return } // no frame yet
            let pts = CMTime(value: self.frameIndex, timescale: CMTimeScale(self.config.fps))
            self.frameIndex += 1
            self.encoder.encode(frame, pts: pts)
        }
        timer.resume()
        self.clock = timer
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                of type: SCStreamOutputType) {
        guard type == .screen,
              CMSampleBufferGetNumSamples(sampleBuffer) > 0,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // Skip frames SCK marks as non-complete (e.g. idle/blank).
        if let attach = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false)
            as? [[SCStreamFrameInfo: Any]], let first = attach.first,
           let raw = first[.status] as? Int, let status = SCFrameStatus(rawValue: raw),
           status != .complete { return }

        // Just stash it; the CFR clock decides when to encode.
        frameLock.lock()
        latestFrame = pixelBuffer
        frameLock.unlock()
    }
}
