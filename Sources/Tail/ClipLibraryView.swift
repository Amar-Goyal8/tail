import SwiftUI
import AVKit
import AppKit

// AppKit AVPlayerView wrapper. SwiftUI's VideoPlayer crashes (_AVKit_SwiftUI
// SIGABRT) in this SwiftPM-built app; AVPlayerView is stable.
struct PlayerView: NSViewRepresentable {
    let player: AVPlayer
    func makeNSView(context: Context) -> AVPlayerView {
        let v = AVPlayerView()
        v.player = player
        v.controlsStyle = .inline
        v.videoGravity = .resizeAspect
        return v
    }
    func updateNSView(_ v: AVPlayerView, context: Context) { v.player = player }
}

// Medal-style clip library: a grid of thumbnail cards. Click a card to watch
// the clip inline and create / copy its share link.
struct ClipLibraryView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var library: LocalLibrary
    @State private var selected: LocalClip?

    private let columns = [GridItem(.adaptive(minimum: 280, maximum: 360), spacing: 16)]

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.06).ignoresSafeArea()
            if library.clips.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(library.clips) { clip in
                            ClipCard(model: model, library: library, clip: clip)
                                .onTapGesture { selected = clip }
                        }
                    }
                    .padding(20)
                }
            }

            // Inline player overlay (in-app, not a separate window).
            if let clip = selected {
                Color.black.opacity(0.6).ignoresSafeArea()
                    .onTapGesture { selected = nil }
                ClipDetail(model: model, library: library, clip: clip,
                           onClose: { selected = nil })
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .animation(.easeOut(duration: 0.15), value: selected?.id)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "film.stack").font(.system(size: 44)).foregroundStyle(.secondary)
            Text("No clips yet").font(.title3.bold())
            Text("Press ⌃⌥C while gaming to grab the last 30 seconds.")
                .foregroundStyle(.secondary)
        }
    }
}

// One clip card: thumbnail + duration + date, with a hover lift.
private struct ClipCard: View {
    @ObservedObject var model: AppModel
    @ObservedObject var library: LocalLibrary
    let clip: LocalClip
    @State private var thumb: NSImage?
    @State private var hover = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                Rectangle().fill(Color.black)
                if let thumb {
                    Image(nsImage: thumb).resizable().aspectRatio(contentMode: .fill)
                } else {
                    ProgressView()
                }
                // play overlay
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 42)).foregroundStyle(.white.opacity(hover ? 0.95 : 0.0))
                    .shadow(radius: 8)
                if clip.link != nil {
                    VStack { HStack { Spacer()
                        Image(systemName: "link").font(.caption2).padding(5)
                            .background(.ultraThinMaterial, in: Circle()).padding(6)
                    }; Spacer() }
                }
            }
            .frame(height: 165).clipped()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(clip.filename.replacingOccurrences(of: ".mp4", with: ""))
                        .font(.system(size: 12, weight: .medium)).lineLimit(1)
                    Text(clip.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(10)
            .background(Color(red: 0.09, green: 0.09, blue: 0.12))
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(hover ? 0.18 : 0.06)))
        .shadow(color: .black.opacity(hover ? 0.5 : 0.2), radius: hover ? 14 : 6, y: 4)
        .scaleEffect(hover ? 1.015 : 1)
        .animation(.easeOut(duration: 0.15), value: hover)
        .onHover { hover = $0 }
        .task(id: clip.id) { thumb = await library.thumbnail(for: clip) }
    }
}

// Inline player + share-link controls.
private struct ClipDetail: View {
    @ObservedObject var model: AppModel
    @ObservedObject var library: LocalLibrary
    let clip: LocalClip
    let onClose: () -> Void

    @State private var player: AVPlayer
    @State private var link: String?
    @State private var state: LinkState = .idle
    enum LinkState { case idle, creating, copied }

    init(model: AppModel, library: LocalLibrary, clip: LocalClip, onClose: @escaping () -> Void) {
        self.model = model; self.library = library; self.clip = clip; self.onClose = onClose
        _player = State(initialValue: AVPlayer(url: library.url(for: clip)))
        _link = State(initialValue: clip.link)
    }

    private func close() { player.pause(); onClose() }

    var body: some View {
        VStack(spacing: 0) {
            PlayerView(player: player)
                .frame(width: 760, height: 428)
                .background(Color.black)
                .onAppear { player.play() }

            HStack(spacing: 12) {
                Text(clip.filename.replacingOccurrences(of: ".mp4", with: ""))
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Button(role: .destructive) {
                    library.delete(clip); close()
                } label: { Image(systemName: "trash") }
                shareButton
                Button("Close") { close() }
            }
            .padding(14)
            .background(Color(red: 0.07, green: 0.07, blue: 0.09))
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.1)))
        .shadow(color: .black.opacity(0.6), radius: 30)
        .padding(40)
    }

    @ViewBuilder private var shareButton: some View {
        if let link {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(link, forType: .string)
                state = .copied
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { if state == .copied { state = .idle } }
            } label: {
                Label(state == .copied ? "Link copied" : "Copy link",
                      systemImage: state == .copied ? "checkmark" : "doc.on.doc")
                    .frame(minWidth: 110)
            }
            .buttonStyle(.borderedProminent).tint(state == .copied ? .green : .accentColor)
        } else {
            Button {
                state = .creating
                Task {
                    let made = await model.createLink(for: clip)
                    link = made
                    state = .idle
                    if let made { // auto-copy on first create
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(made, forType: .string)
                        state = .copied
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { if state == .copied { state = .idle } }
                    }
                }
            } label: {
                Label(state == .creating ? "Creating…" : "Create link", systemImage: "link.badge.plus")
                    .frame(minWidth: 110)
            }
            .buttonStyle(.borderedProminent).disabled(state == .creating)
        }
    }
}
