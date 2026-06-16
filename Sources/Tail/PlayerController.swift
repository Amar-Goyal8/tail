import AVFoundation
import SwiftUI

// Wraps AVPlayer with observable time/duration/playing for a custom seeker.
@MainActor
final class PlayerController: ObservableObject {
    let player = AVPlayer()
    @Published var current: Double = 0
    @Published var duration: Double = 0
    @Published var playing = false
    private var observer: Any?
    private var endObserver: NSObjectProtocol?

    init() {
        observer = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.05, preferredTimescale: 600), queue: .main
        ) { [weak self] t in
            guard let self else { return }
            self.current = t.seconds
            if let d = self.player.currentItem?.duration.seconds, d.isFinite { self.duration = d }
        }
    }

    func load(_ url: URL) {
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        current = 0; duration = 0
        if let e = endObserver { NotificationCenter.default.removeObserver(e) }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in self?.playing = false }
        play()
    }

    func play() { player.play(); playing = true }
    func pause() { player.pause(); playing = false }
    func toggle() { playing ? pause() : play() }

    func seek(to t: Double) {
        let clamped = max(0, min(t, duration.isFinite && duration > 0 ? duration : t))
        player.seek(to: CMTime(seconds: clamped, preferredTimescale: 600),
                    toleranceBefore: .zero, toleranceAfter: .zero)
        current = clamped
    }

    func stop() {
        pause()
        player.replaceCurrentItem(with: nil)
    }

    static func fmt(_ s: Double) -> String {
        guard s.isFinite, s >= 0 else { return "0:00" }
        return String(format: "%d:%02d", Int(s) / 60, Int(s) % 60)
    }
}
