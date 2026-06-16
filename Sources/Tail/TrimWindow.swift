import AppKit
import SwiftUI
import AVKit

// Simple trim editor: preview the clip, drag in/out, share the trimmed range.
struct TrimView: View {
    let url: URL
    let onShare: (Double, Double) -> Void
    let onCancel: () -> Void

    @State private var player: AVPlayer
    @State private var duration: Double = 0
    @State private var start: Double = 0
    @State private var end: Double = 0
    @State private var busy = false

    init(url: URL, onShare: @escaping (Double, Double) -> Void, onCancel: @escaping () -> Void) {
        self.url = url
        self.onShare = onShare
        self.onCancel = onCancel
        _player = State(initialValue: AVPlayer(url: url))
    }

    var body: some View {
        VStack(spacing: 12) {
            PlayerView(player: player)
                .frame(minWidth: 560, minHeight: 315)
                .cornerRadius(8)

            VStack(spacing: 6) {
                HStack {
                    Text("Start \(fmt(start))").font(.caption).monospacedDigit()
                    Slider(value: $start, in: 0...max(duration, 0.1)) { editing in
                        if !editing { seek(start) }
                        if start > end - 0.2 { start = max(0, end - 0.2) }
                    }
                }
                HStack {
                    Text("End \(fmt(end))").font(.caption).monospacedDigit()
                    Slider(value: $end, in: 0...max(duration, 0.1)) { editing in
                        if !editing { seek(end) }
                        if end < start + 0.2 { end = min(duration, start + 0.2) }
                    }
                }
                Text("Clip length: \(fmt(end - start))")
                    .font(.caption2).foregroundStyle(.secondary)
            }

            HStack {
                Button("Cancel") { onCancel() }
                Spacer()
                Button(busy ? "Sharing…" : "Share trimmed") {
                    busy = true
                    onShare(start, end)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(busy)
            }
        }
        .padding(16)
        .onAppear { loadDuration() }
    }

    private func loadDuration() {
        Task {
            let d = (try? await AVURLAsset(url: url).load(.duration))?.seconds ?? 0
            await MainActor.run { duration = d; end = d }
        }
    }

    private func seek(_ t: Double) {
        player.seek(to: CMTime(seconds: t, preferredTimescale: 600),
                    toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func fmt(_ s: Double) -> String {
        let s = max(0, s)
        return String(format: "%d:%05.2f", Int(s) / 60, s.truncatingRemainder(dividingBy: 60))
    }
}

// Hosts TrimView in a standalone window from the menu-bar app.
@MainActor
final class TrimWindowController {
    private var window: NSWindow?

    func show(url: URL, onShare: @escaping (Double, Double) -> Void) {
        let view = TrimView(url: url,
                            onShare: { [weak self] s, e in self?.close(); onShare(s, e) },
                            onCancel: { [weak self] in self?.close() })
        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 460),
                           styleMask: [.titled, .closable], backing: .buffered, defer: false)
        win.title = "Trim — \(url.lastPathComponent)"
        win.contentViewController = NSHostingController(rootView: view)
        win.center()
        win.isReleasedWhenClosed = false
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
        window = win
    }

    private func close() { window?.close(); window = nil }
}
