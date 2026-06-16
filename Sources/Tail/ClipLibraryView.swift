import SwiftUI
import AVKit
import AppKit

// AppKit AVPlayerView wrapper. SwiftUI's VideoPlayer crashes (_AVKit_SwiftUI
// SIGABRT) in this SwiftPM-built app; AVPlayerView is stable.
struct PlayerView: NSViewRepresentable {
    let player: AVPlayer
    var controls: AVPlayerViewControlsStyle = .inline
    func makeNSView(context: Context) -> AVPlayerView {
        let v = AVPlayerView()
        v.player = player
        v.controlsStyle = controls
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
    @State private var selectedIndex: Int?

    private let columns = [GridItem(.adaptive(minimum: 280, maximum: 360), spacing: 18)]

    var body: some View {
        if selectedIndex != nil {
            ClipViewer(model: model, library: library, clips: library.clips, index: $selectedIndex,
                       onExit: { selectedIndex = nil })
        } else if library.clips.isEmpty {
            emptyState.frame(maxWidth: .infinity, maxHeight: .infinity)
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
                        ForEach(Array(library.clips.enumerated()), id: \.element.id) { pair in
                            ClipCard(model: model, library: library, clip: pair.element)
                                .onTapGesture { selectedIndex = pair.offset }
                        }
                    }
                }
                .padding(28)
            }
        }
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
struct ClipCard: View {
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
                // top row: … menu (left) + link badge (right)
                VStack {
                    HStack {
                        Menu {
                            Section("Move to") {
                                Button("Unsorted") { library.move(clip.id, to: nil) }
                                ForEach(library.folders, id: \.self) { f in
                                    Button(f) { library.move(clip.id, to: f) }
                                }
                            }
                            Divider()
                            Button("Delete", role: .destructive) { library.delete(clip) }
                        } label: {
                            Image(systemName: "ellipsis").font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white).frame(width: 26, height: 26)
                                .background(.black.opacity(0.45), in: Circle())
                        }
                        .menuStyle(.borderlessButton).fixedSize().menuIndicator(.hidden)
                        .opacity(hover ? 1 : 0)
                        Spacer()
                        if clip.link != nil {
                            Image(systemName: "link").font(.caption2).foregroundStyle(.white).padding(5)
                                .background(.black.opacity(0.45), in: Circle())
                        }
                    }.padding(7)
                    Spacer()
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

