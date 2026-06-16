import Foundation
import AVFoundation

// Captures the default microphone via AVCaptureSession (SCK only does system
// audio). PCM sample buffers go into the replay buffer's mic ring; at flush
// they're mixed with system audio into one track.
final class MicCapture: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "tail.mic")
    private let onSample: (CMSampleBuffer) -> Void
    private let deviceUID: String?
    private(set) var running = false

    init(deviceUID: String? = nil, onSample: @escaping (CMSampleBuffer) -> Void) {
        self.deviceUID = deviceUID
        self.onSample = onSample
    }

    func start() {
        guard !running else { return }
        let chosen = deviceUID.flatMap { AVCaptureDevice(uniqueID: $0) }
        guard let device = chosen ?? AVCaptureDevice.default(for: .audio),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            FileHandle.standardError.write("[tail] mic: no input device/permission\n".data(using: .utf8)!)
            return
        }
        session.addInput(input)
        let output = AVCaptureAudioDataOutput()
        output.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(output) { session.addOutput(output) }
        session.startRunning()
        running = true
        FileHandle.standardError.write("[tail] mic started\n".data(using: .utf8)!)
    }

    func stop() {
        guard running else { return }
        session.stopRunning()
        running = false
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard CMSampleBufferGetNumSamples(sampleBuffer) > 0,
              let copy = CaptureEngine.detach(sampleBuffer) else { return }
        onSample(copy)
    }
}
