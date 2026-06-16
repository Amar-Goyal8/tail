import Foundation
import AVFoundation
import CoreMedia

// Thread-safe rings of the last `seconds` of media:
//   - video: ENCODED H.264 samples (cheap to keep)
//   - audio: PCM samples from SCK (encoded to AAC at flush time)
// On flush: trim video to a keyframe boundary, take audio from that same
// timestamp, mux both into an .mp4. Video and audio share SCK's clock -> in sync.
final class ReplayBuffer: @unchecked Sendable {
    private let seconds: Double
    private let config: Config
    private let queue = DispatchQueue(label: "tail.replaybuffer")
    private var video: [CMSampleBuffer] = []
    private var audio: [CMSampleBuffer] = []
    private var videoFormat: CMFormatDescription?

    init(seconds: Int, config: Config) {
        self.seconds = Double(seconds)
        self.config = config
    }

    func append(_ sample: CMSampleBuffer) {       // encoded video
        queue.async {
            if self.videoFormat == nil { self.videoFormat = CMSampleBufferGetFormatDescription(sample) }
            self.video.append(sample)
            self.evictAll()
        }
    }

    func appendAudio(_ sample: CMSampleBuffer) {   // PCM audio
        queue.async {
            self.audio.append(sample)
            self.evictAll()
        }
    }

    // Drop video+audio older than `seconds` relative to the newest video frame.
    // Cutoff computed first so the inout eviction never overlaps a read of the
    // same property (Swift exclusive-access rule).
    private func evictAll() {
        guard let newestV = video.last else { return }
        let cutoff = CMSampleBufferGetPresentationTimeStamp(newestV).seconds - seconds
        ReplayBuffer.trim(&video, before: cutoff)
        ReplayBuffer.trim(&audio, before: cutoff)
    }

    private static func trim(_ arr: inout [CMSampleBuffer], before cutoff: Double) {
        while let first = arr.first,
              CMSampleBufferGetPresentationTimeStamp(first).seconds < cutoff {
            arr.removeFirst()
        }
    }

    func flush(to dir: URL) -> URL? {
        let (vSnap, aSnap, fmt) = queue.sync { (video, audio, videoFormat) }
        guard let fmt, !vSnap.isEmpty else { return nil }

        // Start at first video keyframe (clean IDR boundary).
        guard let startIdx = vSnap.firstIndex(where: { isKeyframe($0) }) else { return nil }
        let vClip = Array(vSnap[startIdx...])
        let base = CMSampleBufferGetPresentationTimeStamp(vClip.first!)
        // Audio from the same instant onward.
        let aClip = aSnap.filter { CMSampleBufferGetPresentationTimeStamp($0) >= base }

        let p0 = base.seconds
        let p1 = CMSampleBufferGetPresentationTimeStamp(vClip.last!).seconds
        log("flush: vframes=\(vClip.count) aframes=\(aClip.count) span=\(String(format: "%.2f", p1 - p0))s")

        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("tail-\(Int(Date().timeIntervalSince1970)).mp4")
        guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mp4) else { return nil }

        // Video: passthrough (already H.264).
        let vIn = AVAssetWriterInput(mediaType: .video, outputSettings: nil, sourceFormatHint: fmt)
        vIn.expectsMediaDataInRealTime = false
        guard writer.canAdd(vIn) else { return nil }
        writer.add(vIn)

        // Audio: encode PCM -> AAC on write.
        let aSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: config.audioSampleRate,
            AVNumberOfChannelsKey: config.audioChannels,
            AVEncoderBitRateKey: config.audioBitrate,
        ]
        var aIn: AVAssetWriterInput?
        if !aClip.isEmpty {
            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: aSettings)
            input.expectsMediaDataInRealTime = false
            if writer.canAdd(input) { writer.add(input); aIn = input }
        }

        let ok = writer.startWriting()
        if !ok || writer.status != .writing {
            log("startWriting failed ok=\(ok) status=\(writer.status.rawValue) err=\(writer.error?.localizedDescription ?? "?")")
            return nil
        }
        writer.startSession(atSourceTime: .zero)   // samples retimed to start at 0

        // Pull-driven mux: each input drains its queue when ready. Lets the
        // muxer interleave both tracks instead of deadlocking on one.
        let group = DispatchGroup()
        feed(vIn, samples: vClip, base: base, queue: DispatchQueue(label: "tail.mux.v"), group: group)
        if let aIn {
            feed(aIn, samples: aClip, base: base, queue: DispatchQueue(label: "tail.mux.a"), group: group)
        }
        group.wait()

        let sem = DispatchSemaphore(value: 0)
        writer.finishWriting { sem.signal() }
        sem.wait()
        if writer.status != .completed {
            log("writer FAILED status=\(writer.status.rawValue) err=\(writer.error?.localizedDescription ?? "?")")
            return nil
        }
        return url
    }

    // Drain `samples` into `input` as it signals readiness; finish + leave once.
    // The callback fires serially on `queue`, so a class-held cursor is safe and
    // keeps Swift 6 concurrency checking happy (no loose captured vars).
    private func feed(_ input: AVAssetWriterInput, samples: [CMSampleBuffer], base: CMTime,
                      queue: DispatchQueue, group: DispatchGroup) {
        group.enter()
        let cursor = Feeder(samples: samples)
        input.requestMediaDataWhenReady(on: queue) { [weak self] in
            guard let self else { return }
            while input.isReadyForMoreMediaData {
                guard let s = cursor.next() else {
                    if cursor.finish() { input.markAsFinished(); group.leave() }
                    return
                }
                if let r = self.retime(s, base: base) { input.append(r) }
            }
        }
    }

    // Single-consumer cursor over a sample list (accessed only from one serial queue).
    private final class Feeder: @unchecked Sendable {
        private var samples: ArraySlice<CMSampleBuffer>
        private var finished = false
        init(samples: [CMSampleBuffer]) { self.samples = samples[...] }
        func next() -> CMSampleBuffer? {
            guard let s = samples.first else { return nil }
            samples = samples.dropFirst()
            return s
        }
        func finish() -> Bool { if finished { return false }; finished = true; return true }
    }

    private func isKeyframe(_ sb: CMSampleBuffer) -> Bool {
        guard let arr = CMSampleBufferGetSampleAttachmentsArray(sb, createIfNecessary: false)
                as? [[CFString: Any]], let first = arr.first else { return true }
        if let notSync = first[kCMSampleAttachmentKey_NotSync] as? Bool { return !notSync }
        return true
    }

    // Rebase PTS/DTS so the clip starts at zero.
    private func retime(_ sb: CMSampleBuffer, base: CMTime) -> CMSampleBuffer? {
        let count = CMSampleBufferGetNumSamples(sb)
        var timing = CMSampleTimingInfo()
        CMSampleBufferGetSampleTimingInfo(sb, at: 0, timingInfoOut: &timing)
        if timing.presentationTimeStamp != .invalid {
            timing.presentationTimeStamp = CMTimeSubtract(timing.presentationTimeStamp, base)
        }
        if timing.decodeTimeStamp != .invalid {
            timing.decodeTimeStamp = CMTimeSubtract(timing.decodeTimeStamp, base)
        }
        var out: CMSampleBuffer?
        // For multi-sample audio buffers, a single timing entry (with duration)
        // applies uniformly when entryCount = 1.
        CMSampleBufferCreateCopyWithNewTiming(allocator: kCFAllocatorDefault,
                                              sampleBuffer: sb,
                                              sampleTimingEntryCount: 1,
                                              sampleTimingArray: &timing,
                                              sampleBufferOut: &out)
        _ = count
        return out
    }

    private func log(_ s: String) {
        FileHandle.standardError.write("[tail] \(s)\n".data(using: .utf8)!)
    }
}
