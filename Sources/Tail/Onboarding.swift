import AppKit
import SwiftUI

// First-launch walkthrough: what Tail does + the permissions it needs.
struct OnboardingView: View {
    let onDone: () -> Void
    let onOpenScreenRecording: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("🎬").font(.system(size: 56))
            Text("Welcome to Tail").font(.title).bold()
            Text("Clip the last 30 seconds of your game and share a link that plays instantly — even in Discord.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                step("1", "Grant Screen Recording", "So Tail can capture your screen + game audio.")
                step("2", "Press ⌃⌥C while playing", "Instantly saves the last 30 seconds.")
                step("3", "Link is copied", "Paste it anywhere — it plays inline in Discord.")
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.1)))

            HStack {
                Button("Open Screen Recording settings") { onOpenScreenRecording() }
                Spacer()
                Button("Get started") { onDone() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 460)
    }

    private func step(_ n: String, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(n).font(.headline).frame(width: 22, height: 22)
                .background(Circle().fill(Color.accentColor.opacity(0.25)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(body).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

@MainActor
final class OnboardingWindowController {
    private var window: NSWindow?
    private static let seenKey = "tail.onboarded"

    static var hasOnboarded: Bool { UserDefaults.standard.bool(forKey: seenKey) }

    func showIfNeeded(openScreenRecording: @escaping () -> Void) {
        guard !Self.hasOnboarded else { return }
        let view = OnboardingView(
            onDone: { [weak self] in
                UserDefaults.standard.set(true, forKey: Self.seenKey)
                self?.window?.close(); self?.window = nil
            },
            onOpenScreenRecording: openScreenRecording)
        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 420),
                           styleMask: [.titled], backing: .buffered, defer: false)
        win.title = "Welcome to Tail"
        win.contentViewController = NSHostingController(rootView: view)
        win.center(); win.isReleasedWhenClosed = false
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
        window = win
    }
}
