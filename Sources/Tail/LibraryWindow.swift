import AppKit
import SwiftUI

// "My clips" library: list past clips with copy-link, open, and delete.
struct LibraryView: View {
    let client: ClipsClient

    @State private var clips: [ClipSummary] = []
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("My Clips").font(.headline)
                Spacer()
                Button(action: reload) { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.borderless)
            }.padding(12)
            Divider()

            if loading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error {
                Text(error).foregroundStyle(.red).padding()
            } else if clips.isEmpty {
                Text("No clips yet. Press ⌃⌥C in a game to make one.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(clips) { clip in row(clip); Divider() }
                    }
                }
            }
        }
        .frame(width: 460, height: 520)
        .onAppear(perform: reload)
    }

    private func row(_ clip: ClipSummary) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(clip.title?.isEmpty == false ? clip.title! : "Clip \(clip.id)")
                    .font(.system(size: 13, weight: .medium)).lineLimit(1)
                Text("\(clip.width)×\(clip.height) · \(Int(clip.durationSec))s · \(date(clip.createdAt))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Copy link") { copy(clip.link) }.buttonStyle(.borderless).font(.caption)
            Button(action: { open(clip.link) }) { Image(systemName: "play.circle") }
                .buttonStyle(.borderless)
            Button(action: { remove(clip) }) { Image(systemName: "trash") }
                .buttonStyle(.borderless).foregroundStyle(.red)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
    }

    private func reload() {
        loading = true; error = nil
        Task {
            do {
                let list = try await client.list()
                await MainActor.run { clips = list; loading = false }
            } catch {
                await MainActor.run { self.error = error.localizedDescription; loading = false }
            }
        }
    }

    private func remove(_ clip: ClipSummary) {
        Task {
            try? await client.delete(clip.id)
            await MainActor.run { clips.removeAll { $0.id == clip.id } }
        }
    }

    private func copy(_ s: String) {
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(s, forType: .string)
    }
    private func open(_ s: String) { if let u = URL(string: s) { NSWorkspace.shared.open(u) } }
    private func date(_ iso: String) -> String { String(iso.prefix(10)) }
}

@MainActor
final class LibraryWindowController {
    private var window: NSWindow?
    func show(client: ClipsClient) {
        if let window { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 520),
                           styleMask: [.titled, .closable], backing: .buffered, defer: false)
        win.title = "Tail — My Clips"
        win.contentViewController = NSHostingController(rootView: LibraryView(client: client))
        win.center(); win.isReleasedWhenClosed = false
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
        window = win
    }
}
