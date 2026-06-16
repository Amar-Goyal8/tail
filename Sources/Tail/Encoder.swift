import Foundation
import VideoToolbox
import CoreMedia

// HW HEVC encoder via VideoToolbox. Apple Silicon media engine -> cheap high-FPS.
// Forces keyframe ~every 1s so replay flush has clean IDR boundaries.
final class Encoder: @unchecked Sendable {
    private var session: VTCompressionSession?
    private let config: Config
    private let onEncoded: (CMSampleBuffer) -> Void
    private var frameCount: Int64 = 0

    init(config: Config, onEncoded: @escaping (CMSampleBuffer) -> Void) {
        self.config = config
        self.onEncoded = onEncoded
        setup()
    }

    private func setup() {
        let status = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: Int32(config.width),
            height: Int32(config.height),
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: nil,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: nil,
            refcon: nil,
            compressionSessionOut: &session
        )
        guard status == noErr, let session else {
            FileHandle.standardError.write("VTCompressionSessionCreate failed: \(status)\n".data(using: .utf8)!)
            return
        }
        func p(_ key: CFString, _ value: CFTypeRef) {
            _ = VTSessionSetProperty(session, key: key, value: value)
        }
        p(kVTCompressionPropertyKey_RealTime, kCFBooleanTrue)
        p(kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_High_AutoLevel)
        p(kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanFalse)
        p(kVTCompressionPropertyKey_AverageBitRate, config.bitrate as CFNumber)
        // Keyframe every `fps` frames ~= 1s.
        p(kVTCompressionPropertyKey_MaxKeyFrameInterval, config.fps as CFNumber)
        p(kVTCompressionPropertyKey_ExpectedFrameRate, config.fps as CFNumber)
        VTCompressionSessionPrepareToEncodeFrames(session)
    }

    func encode(_ pixelBuffer: CVPixelBuffer, pts: CMTime) {
        guard let session else { return }
        frameCount += 1
        VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: pixelBuffer,
            presentationTimeStamp: pts,
            duration: CMTime(value: 1, timescale: Int32(config.fps)),
            frameProperties: nil,
            infoFlagsOut: nil
        ) { [weak self] status, _, sample in
            guard status == noErr, let sample else { return }
            self?.onEncoded(sample)
        }
    }
}
