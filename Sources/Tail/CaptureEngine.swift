import Foundation
import ScreenCaptureKit
import CoreMedia

// What to capture: a whole display, or a single window (the game).
enum CaptureSource: @unchecked Sendable {
    case display(SCDisplay)
    case window(SCWindow)
}

// ScreenCaptureKit capture -> Encoder (video) + ReplayBuffer (audio PCM).
// Video uses SCK's real PTS so it stays in sync with the audio clock.
final class CaptureEngine: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    private let config: Config
    private let encoder: Encoder
    private let buffer: ReplayBuffer
    private var stream: SCStream?
    private let videoQueue = DispatchQueue(label: "tail.capture.video")
    private let audioQueue = DispatchQueue(label: "tail.capture.audio")

    init(config: Config, encoder: Encoder, buffer: ReplayBuffer) {
        self.config = config
        self.encoder = encoder
        self.buffer = buffer
    }

    // List capturable sources for the picker menu.
    static func sources() async throws -> (displays: [SCDisplay], windows: [SCWindow]) {
        let content = try await SCShareableContent.excludingDesktopWindows(false,
                                                                           onScreenWindowsOnly: true)
        // Only real app windows with a title and sane size.
        let windows = content.windows.filter {
            ($0.title?.isEmpty == false) && $0.frame.width > 200 && $0.frame.height > 200
                && $0.owningApplication?.bundleIdentifier != "com.tail.clipper"
        }
        return (content.displays, windows)
    }

    func start(source: CaptureSource? = nil) async throws {
        try? await stop()
        let content = try await SCShareableContent.excludingDesktopWindows(false,
                                                                           onScreenWindowsOnly: true)
        let filter: SCContentFilter
        let label: String
        switch source {
        case .window(let w):
            filter = SCContentFilter(desktopIndependentWindow: w)
            label = "window: \(w.title ?? "?")"
        case .display(let d):
            filter = SCContentFilter(display: d, excludingWindows: [])
            label = "display \(d.displayID)"
        case .none:
            guard let display = content.displays.first else {
                throw NSError(domain: "tail", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "no display"])
            }
            filter = SCContentFilter(display: display, excludingWindows: [])
            label = "display \(display.displayID)"
        }

        let cfg = SCStreamConfiguration()
        cfg.width = config.width
        cfg.height = config.height
        cfg.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(config.fps))
        cfg.pixelFormat = kCVPixelFormatType_32BGRA
        cfg.queueDepth = 8
        cfg.showsCursor = true
        // System audio.
        cfg.capturesAudio = true
        cfg.sampleRate = config.audioSampleRate
        cfg.channelCount = config.audioChannels

        let stream = SCStream(filter: filter, configuration: cfg, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: videoQueue)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioQueue)
        try await stream.startCapture()
        self.stream = stream
        log("capture started \(config.width)x\(config.height)@\(config.fps) +audio [\(label)]")
    }

    func stop() async throws {
        if let s = stream { try? await s.stopCapture() }
        stream = nil
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                of type: SCStreamOutputType) {
        switch type {
        case .screen: handleVideo(sampleBuffer)
        case .audio: handleAudio(sampleBuffer)
        default: break
        }
    }

    private func handleVideo(_ sampleBuffer: CMSampleBuffer) {
        guard CMSampleBufferGetNumSamples(sampleBuffer) > 0,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        // Skip frames SCK marks non-complete (idle/blank).
        if let attach = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false)
            as? [[SCStreamFrameInfo: Any]], let first = attach.first,
           let raw = first[.status] as? Int, let status = SCFrameStatus(rawValue: raw),
           status != .complete { return }
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        encoder.encode(pixelBuffer, pts: pts)
    }

    private func handleAudio(_ sampleBuffer: CMSampleBuffer) {
        guard CMSampleBufferGetNumSamples(sampleBuffer) > 0,
              let detached = Self.detach(sampleBuffer) else { return }
        buffer.appendAudio(detached)
    }

    // Copy a sample buffer's PCM into a freshly-allocated, SCK-independent one.
    static func detach(_ sb: CMSampleBuffer) -> CMSampleBuffer? {
        guard let fmt = CMSampleBufferGetFormatDescription(sb),
              let src = CMSampleBufferGetDataBuffer(sb) else { return nil }
        var totalLen = 0
        guard CMBlockBufferGetDataPointer(src, atOffset: 0, lengthAtOffsetOut: nil,
                totalLengthOut: &totalLen, dataPointerOut: nil) == kCMBlockBufferNoErr,
              totalLen > 0 else { return nil }

        var newBlock: CMBlockBuffer?
        guard CMBlockBufferCreateWithMemoryBlock(allocator: kCFAllocatorDefault, memoryBlock: nil,
                blockLength: totalLen, blockAllocator: kCFAllocatorDefault, customBlockSource: nil,
                offsetToData: 0, dataLength: totalLen, flags: 0, blockBufferOut: &newBlock)
                == kCMBlockBufferNoErr,
              let newBlock,
              CMBlockBufferAssureBlockMemory(newBlock) == kCMBlockBufferNoErr else { return nil }

        // Copy src bytes into the new block.
        let bytes = UnsafeMutableRawPointer.allocate(byteCount: totalLen, alignment: 1)
        defer { bytes.deallocate() }
        guard CMBlockBufferCopyDataBytes(src, atOffset: 0, dataLength: totalLen,
                destination: bytes) == kCMBlockBufferNoErr,
              CMBlockBufferReplaceDataBytes(with: bytes, blockBuffer: newBlock,
                offsetIntoDestination: 0, dataLength: totalLen) == kCMBlockBufferNoErr else { return nil }

        let numSamples = CMSampleBufferGetNumSamples(sb)
        var timing = CMSampleTimingInfo()
        CMSampleBufferGetSampleTimingInfo(sb, at: 0, timingInfoOut: &timing)
        var timingArr = [timing]
        var sizeArr = [totalLen / max(numSamples, 1)]
        var out: CMSampleBuffer?
        guard CMSampleBufferCreateReady(allocator: kCFAllocatorDefault, dataBuffer: newBlock,
                formatDescription: fmt, sampleCount: numSamples, sampleTimingEntryCount: 1,
                sampleTimingArray: &timingArr, sampleSizeEntryCount: 1, sampleSizeArray: &sizeArr,
                sampleBufferOut: &out) == noErr else { return nil }
        return out
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        log("STREAM STOPPED: \(error.localizedDescription)")
    }

    private func log(_ s: String) {
        FileHandle.standardError.write("[tail] \(s)\n".data(using: .utf8)!)
    }
}
