import Foundation
import AVFoundation
import CoreMedia

// Thread-safe ring of ENCODED frames. Holds last `seconds` of HEVC samples.
// On flush: trim to a keyframe boundary, mux to .mp4 via passthrough writer.
final class ReplayBuffer: @unchecked Sendable {
    private let seconds: Double
    private let queue = DispatchQueue(label: "tail.replaybuffer")
    private var samples: [CMSampleBuffer] = []
    private var formatDesc: CMFormatDescription?

    init(seconds: Int) {
        self.seconds = Double(seconds)
    }

    // Called from encoder output callback for every encoded frame.
    func append(_ sample: CMSampleBuffer) {
        queue.async {
            if self.formatDesc == nil {
                self.formatDesc = CMSampleBufferGetFormatDescription(sample)
            }
            self.samples.append(sample)
            self.evict()
        }
    }

    // Drop frames older than `seconds` relative to newest pts.
    private func evict() {
        guard let last = samples.last else { return }
        let newest = CMSampleBufferGetPresentationTimeStamp(last).seconds
        let cutoff = newest - seconds
        while let first = samples.first,
              CMSampleBufferGetPresentationTimeStamp(first).seconds < cutoff {
            samples.removeFirst()
        }
    }

    // Snapshot + mux. Returns output URL on success.
    func flush(to dir: URL) -> URL? {
        let (snapshot, fmt) = queue.sync { (samples, formatDesc) }
        guard let fmt, !snapshot.isEmpty else { return nil }

        // Find first keyframe so decode starts clean (IDR boundary).
        guard let startIdx = snapshot.firstIndex(where: { isKeyframe($0) }) else { return nil }
        let clip = Array(snapshot[startIdx...])

        // Diagnostics: span vs frame count -> real fps + duration.
        let p0 = CMSampleBufferGetPresentationTimeStamp(clip.first!).seconds
        let p1 = CMSampleBufferGetPresentationTimeStamp(clip.last!).seconds
        let span = p1 - p0
        let fps = span > 0 ? Double(clip.count) / span : 0
        FileHandle.standardError.write(
            "[tail] flush: total=\(snapshot.count) clip=\(clip.count) span=\(String(format: "%.2f", span))s fps=\(String(format: "%.1f", fps))\n"
                .data(using: .utf8)!)

        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("tail-\(Int(Date().timeIntervalSince1970)).mp4")

        guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mp4) else { return nil }
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: nil, sourceFormatHint: fmt)
        input.expectsMediaDataInRealTime = false
        guard writer.canAdd(input) else { return nil }
        writer.add(input)

        // Samples get retimed to start at 0 -> session must also start at 0,
        // else AVAssetWriter writes an edit list QuickTime reads as inflated duration.
        let startPTS = CMSampleBufferGetPresentationTimeStamp(clip.first!)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        for sample in clip {
            // Wait for input ready (passthrough is fast but be safe).
            while !input.isReadyForMoreMediaData { usleep(500) }
            guard let retimed = retime(sample, base: startPTS) else { continue }
            input.append(retimed)
        }
        input.markAsFinished()

        let sem = DispatchSemaphore(value: 0)
        writer.finishWriting { sem.signal() }
        sem.wait()
        return writer.status == .completed ? url : nil
    }

    private func isKeyframe(_ sb: CMSampleBuffer) -> Bool {
        guard let arr = CMSampleBufferGetSampleAttachmentsArray(sb, createIfNecessary: false)
                as? [[CFString: Any]], let first = arr.first else { return true }
        // Keyframe if NotSync absent or false.
        if let notSync = first[kCMSampleAttachmentKey_NotSync] as? Bool { return !notSync }
        return true
    }

    // Rebase PTS so clip starts at zero.
    private func retime(_ sb: CMSampleBuffer, base: CMTime) -> CMSampleBuffer? {
        var timing = CMSampleTimingInfo()
        CMSampleBufferGetSampleTimingInfo(sb, at: 0, timingInfoOut: &timing)
        timing.presentationTimeStamp = CMTimeSubtract(timing.presentationTimeStamp, base)
        if timing.decodeTimeStamp != .invalid {
            timing.decodeTimeStamp = CMTimeSubtract(timing.decodeTimeStamp, base)
        }
        var out: CMSampleBuffer?
        CMSampleBufferCreateCopyWithNewTiming(allocator: kCFAllocatorDefault,
                                              sampleBuffer: sb,
                                              sampleTimingEntryCount: 1,
                                              sampleTimingArray: &timing,
                                              sampleBufferOut: &out)
        return out
    }
}
