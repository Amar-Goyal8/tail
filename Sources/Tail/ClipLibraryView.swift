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
    @State private var selecting = false
    @State private var selection: Set<String> = []

    private let columns = [GridItem(.adaptive(minimum: 280, maximum: 360), spacing: 18)]

    var body: some View {
        if selectedIndex != nil {
            ClipViewer(model: model, library: library, clips: library.clips, index: $selectedIndex,
                       onExit: { selectedIndex = nil })
        } else if library.clips.isEmpty {
            emptyState.frame(maxWidth: .infinity, maxHeight: .infinity)
                .task { await library.syncCloud() }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    LazyVGrid(columns: columns, spacing: 18) {
                        ForEach(Array(library.clips.enumerated()), id: \.element.id) { pair in
                            ClipCard(model: model, library: library, clip: pair.element,
                                     selecting: selecting, isSelected: selection.contains(pair.element.id))
                                .onTapGesture {
                                    if selecting { toggle(pair.element.id) } else { selectedIndex = pair.offset }
                                }
                        }
                    }
                }
                .padding(28)
            }
            .overlay(alignment: .bottom) { if selecting { selectionBar } }
            .task { await library.syncCloud() }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("CLIPS").font(Theme.display(30)).foregroundStyle(Theme.text)
            Text("\(library.clips.count)").font(Theme.ui(14, .semibold))
                .foregroundStyle(Theme.primaryHi)
                .padding(.horizontal, 8).padding(.vertical, 2)
                .background(Capsule().fill(Theme.primary.opacity(0.18)))
            Spacer()
            // select-mode toggle (circle)
            Button { selecting.toggle(); if !selecting { selection.removeAll() } } label: {
                Image(systemName: selecting ? "checkmark.circle.fill" : "circle.dashed")
                    .font(.system(size: 20)).foregroundStyle(selecting ? Theme.primaryHi : Theme.textDim)
            }.buttonStyle(.plain).help("Select multiple")
        }
    }

    private var selectionBar: some View {
        HStack(spacing: 12) {
            Text("\(selection.count) selected").font(Theme.ui(13, .semibold)).foregroundStyle(Theme.text)
            Spacer()
            Menu {
                Button("Unsorted") { library.moveMany(selection, to: nil); endSelect() }
                ForEach(library.folders, id: \.self) { f in
                    Button(f) { library.moveMany(selection, to: f); endSelect() }
                }
            } label: { Label("Move to", systemImage: "folder") }
                .menuStyle(.borderlessButton).fixedSize()
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(Theme.elevated, in: Capsule()).overlay(Capsule().stroke(Theme.stroke))
                .foregroundStyle(Theme.text).font(Theme.ui(13, .semibold))
            Button { library.deleteMany(selection); endSelect() } label: {
                Label("Delete", systemImage: "trash")
            }.buttonStyle(TailButtonStyle(kind: .action)).disabled(selection.isEmpty)
            Button("Done") { endSelect() }.buttonStyle(TailButtonStyle(kind: .ghost))
        }
        .padding(14)
        .background(Theme.surface).overlay(RoundedRectangle(cornerRadius: Theme.R.lg).stroke(Theme.stroke))
        .clipShape(RoundedRectangle(cornerRadius: Theme.R.lg))
        .shadow(color: .black.opacity(0.5), radius: 20, y: 6)
        .padding(20)
    }

    private func toggle(_ id: String) {
        if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
    }
    private func endSelect() { selecting = false; selection.removeAll() }

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
    var selecting = false
    var isSelected = false
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
                // top row: select circle / … menu (left) + link badge (right)
                VStack {
                    HStack {
                        if selecting {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20)).foregroundStyle(isSelected ? Theme.primaryHi : .white)
                                .background(Circle().fill(.black.opacity(0.4)).frame(width: 22, height: 22))
                        } else {
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
                        }
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

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(clip.game ?? "Clip").font(Theme.ui(13, .semibold))
                        .foregroundStyle(Theme.text).lineLimit(1)
                    Text("\(clip.game ?? "Unknown") · \(Self.relative(clip.createdAt))")
                        .font(Theme.ui(11)).foregroundStyle(Theme.textDim).lineLimit(1)
                }
                Spacer(minLength: 6)
                if let v = clip.views {
                    HStack(spacing: 5) {
                        Image(systemName: "eye").font(.system(size: 11))
                        Text("\(v)").font(Theme.mono(11, .medium))
                    }.foregroundStyle(Theme.textDim)
                } else if clip.link == nil {
                    Text("LOCAL").font(Theme.mono(10, .medium)).foregroundStyle(Theme.textFaint)
                }
            }
            .padding(.horizontal, 13).padding(.vertical, 11)
            .background(Theme.card)
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.R.lg))
        .overlay(RoundedRectangle(cornerRadius: Theme.R.lg)
            .stroke(isSelected ? Theme.primaryHi : (hover ? Theme.primary.opacity(0.5) : Theme.stroke),
                    lineWidth: isSelected ? 2 : 1))
        .shadow(color: (hover || isSelected ? Theme.primary : .black).opacity(hover || isSelected ? 0.4 : 0.25), radius: hover ? 16 : 7, y: 5)
        .scaleEffect(hover ? 1.015 : 1)
        .animation(.easeOut(duration: 0.15), value: hover)
        .onHover { hover = $0 }
        .task(id: clip.id) { thumb = await library.thumbnail(for: clip) }
    }

    static func relative(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter(); f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: Date())
    }
}

