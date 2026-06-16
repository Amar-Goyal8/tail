import Foundation
import AVFoundation

// Mixes a mic audio track into a base clip (video + system audio) producing one
// combined audio track. Uses AVAssetReaderAudioMixOutput so AVFoundation does
// the mixing; video is copied through (no re-encode, keeps quality/fps).
enum Mixer {
    // base = clip with video + system audio. micURL = mic-only audio file.
    static func mix(base baseURL: URL, micURL: URL, config: Config) async -> URL? {
        let baseAsset = AVURLAsset(url: baseURL)
        let micAsset = AVURLAsset(url: micURL)
        guard let vTrack = try? await baseAsset.loadTracks(withMediaType: .video).first,
              let sysTrack = try? await baseAsset.loadTracks(withMediaType: .audio).first,
              let micTrack = try? await micAsset.loadTracks(withMediaType: .audio).first
        else { return nil }

        // Composition: video + both audio tracks. The audio-mix output blends them.
        let comp = AVMutableComposition()
        guard let cv = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let ca1 = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid),
              let ca2 = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        else { return nil }

        let vRange = (try? await vTrack.load(.timeRange)) ?? CMTimeRange(start: .zero, duration: .zero)
        try? cv.insertTimeRange(vRange, of: vTrack, at: .zero)
        if let sr = try? await sysTrack.load(.timeRange) { try? ca1.insertTimeRange(sr, of: sysTrack, at: .zero) }
        if let mr = try? await micTrack.load(.timeRange) { try? ca2.insertTimeRange(mr, of: micTrack, at: .zero) }

        let audioMix = AVMutableAudioMix()
        let p1 = AVMutableAudioMixInputParameters(track: ca1); p1.setVolume(1.0, at: .zero)
        let p2 = AVMutableAudioMixInputParameters(track: ca2); p2.setVolume(1.0, at: .zero)
        audioMix.inputParameters = [p1, p2]

        guard let reader = try? AVAssetReader(asset: comp) else { return nil }
        let vOut = AVAssetReaderTrackOutput(track: cv, outputSettings: nil) // passthrough
        let aOut = AVAssetReaderAudioMixOutput(audioTracks: [ca1, ca2], audioSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: config.audioSampleRate,
            AVNumberOfChannelsKey: config.audioChannels,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ])
        aOut.audioMix = audioMix
        guard reader.canAdd(vOut), reader.canAdd(aOut) else { return nil }
        reader.add(vOut); reader.add(aOut)

        let out = baseURL.deletingPathExtension().appendingPathExtension("mixed.mp4")
        try? FileManager.default.removeItem(at: out)
        guard let writer = try? AVAssetWriter(outputURL: out, fileType: .mp4) else { return nil }
        let vFmt = (try? await vTrack.load(.formatDescriptions))?.first
        let vIn = AVAssetWriterInput(mediaType: .video, outputSettings: nil, sourceFormatHint: vFmt)
        vIn.expectsMediaDataInRealTime = false
        let aIn = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: config.audioSampleRate,
            AVNumberOfChannelsKey: config.audioChannels,
            AVEncoderBitRateKey: config.audioBitrate,
        ])
        aIn.expectsMediaDataInRealTime = false
        guard writer.canAdd(vIn), writer.canAdd(aIn) else { return nil }
        writer.add(vIn); writer.add(aIn)

        guard reader.startReading(), writer.startWriting() else { return nil }
        writer.startSession(atSourceTime: .zero)

        let group = DispatchGroup()
        drain(vIn, from: vOut, queue: DispatchQueue(label: "tail.mix.v"), group: group)
        drain(aIn, from: aOut, queue: DispatchQueue(label: "tail.mix.a"), group: group)
        await withCheckedContinuation { cont in group.notify(queue: .global()) { cont.resume() } }

        await withCheckedContinuation { cont in writer.finishWriting { cont.resume() } }
        reader.cancelReading()
        return writer.status == .completed ? out : nil
    }

    private static func drain(_ input: AVAssetWriterInput, from output: AVAssetReaderOutput,
                              queue: DispatchQueue, group: DispatchGroup) {
        group.enter()
        var done = false
        input.requestMediaDataWhenReady(on: queue) {
            while input.isReadyForMoreMediaData {
                if let sb = output.copyNextSampleBuffer() {
                    input.append(sb)
                } else {
                    if !done { done = true; input.markAsFinished(); group.leave() }
                    return
                }
            }
        }
    }
}
