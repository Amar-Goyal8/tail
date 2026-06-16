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
            if library.clips.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text("CLIPS").font(Theme.display(30)).foregroundStyle(Theme.text)
                            Text("\(library.clips.count)").font(Theme.ui(14, .semibold))
                                .foregroundStyle(Theme.primaryHi)
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background(Capsule().fill(Theme.primary.opacity(0.18)))
                            Spacer()
                        }
                        LazyVGrid(columns: columns, spacing: 18) {
                            ForEach(library.clips) { clip in
                                ClipCard(model: model, library: library, clip: clip)
                                    .onTapGesture { selected = clip }
                            }
                        }
                    }
                    .padding(28)
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
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(Theme.primary.opacity(0.14)).frame(width: 88, height: 88)
                Image(systemName: "square.grid.2x2.fill").font(.system(size: 34))
                    .foregroundStyle(Theme.primaryHi)
            }
            Text("NO CLIPS YET").font(Theme.display(22)).foregroundStyle(Theme.text)
            Text("Press ⌃⌥C while gaming to grab the last 30 seconds.")
                .font(Theme.ui(13)).foregroundStyle(Theme.textDim)
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
                VStack(alignment: .leading, spacing: 3) {
                    Text(clip.link != nil ? "Shared clip" : "Local clip")
                        .font(Theme.ui(13, .semibold)).foregroundStyle(Theme.text).lineLimit(1)
                    Text(clip.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(Theme.ui(11)).foregroundStyle(Theme.textDim)
                }
                Spacer()
            }
            .padding(12)
            .background(Theme.card)
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.R.lg))
        .overlay(RoundedRectangle(cornerRadius: Theme.R.lg).stroke(hover ? Theme.primary.opacity(0.5) : Theme.stroke))
        .shadow(color: (hover ? Theme.primary : .black).opacity(hover ? 0.4 : 0.25), radius: hover ? 16 : 7, y: 5)
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

            HStack(spacing: 10) {
                Text(clip.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(Theme.ui(12)).foregroundStyle(Theme.textDim)
                Spacer()
                Button { library.delete(clip); close() } label: {
                    Image(systemName: "trash")
                }.buttonStyle(TailButtonStyle(kind: .ghost))
                shareButton
                Button { close() } label: { Text("Close") }
                    .buttonStyle(TailButtonStyle(kind: .ghost))
            }
            .padding(14)
            .background(Theme.surface)
        }
        .frame(width: 760)
        .clipShape(RoundedRectangle(cornerRadius: Theme.R.lg))
        .overlay(RoundedRectangle(cornerRadius: Theme.R.lg).stroke(Theme.strokeHi))
        .shadow(color: .black.opacity(0.6), radius: 40)
        .padding(40)
    }

    @ViewBuilder private var shareButton: some View {
        if let link {
            Button {
                copyLink(link)
            } label: {
                Label(state == .copied ? "Link copied" : "Copy link",
                      systemImage: state == .copied ? "checkmark" : "link")
                    .frame(minWidth: 96)
            }
            .buttonStyle(TailButtonStyle(kind: state == .copied ? .primary : .action))
        } else {
            Button {
                state = .creating
                Task {
                    let made = await model.createLink(for: clip)
                    link = made
                    if let made { copyLink(made) } else { state = .idle }
                }
            } label: {
                Label(state == .creating ? "Creating…" : "Create link", systemImage: "link.badge.plus")
                    .frame(minWidth: 96)
            }
            .buttonStyle(TailButtonStyle(kind: .action)).disabled(state == .creating)
        }
    }

    private func copyLink(_ s: String) {
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(s, forType: .string)
        state = .copied
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { if state == .copied { state = .idle } }
    }
}
