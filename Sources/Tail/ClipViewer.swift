import SwiftUI
import AVKit
import AppKit

// Full theater viewer: big player + custom seeker, prev/next between clips,
// exit to gallery, and an info panel (date, game, author, views, description).
struct ClipViewer: View {
    @ObservedObject var model: AppModel
    @ObservedObject var library: LocalLibrary
    @Binding var index: Int?
    let onExit: () -> Void

    @StateObject private var pc = PlayerController()
    @State private var descDraft = ""
    @State private var linkState: LinkState = .idle
    enum LinkState { case idle, creating, copied }

    private var clip: LocalClip? {
        guard let i = index, library.clips.indices.contains(i) else { return nil }
        return library.clips[i]
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            if let clip {
                VStack(spacing: 0) {
                    topBar(clip)
                    theater(clip)
                    infoPanel(clip)
                }
            }
        }
        .onAppear { reload() }
        .onChange(of: index) { _, _ in reload() }
        .onDisappear { pc.stop() }
    }

    // MARK: Top bar
    private func topBar(_ clip: LocalClip) -> some View {
        HStack(spacing: 12) {
            Button { pc.stop(); onExit() } label: {
                HStack(spacing: 6) { Image(systemName: "chevron.left"); Text("Gallery") }
            }.buttonStyle(TailButtonStyle(kind: .ghost))
            Spacer()
            Text(clip.game ?? "Clip").font(Theme.display(18)).foregroundStyle(Theme.text)
            Spacer()
            shareButton(clip)
        }
        .padding(.horizontal, 22).padding(.vertical, 14)
    }

    // MARK: Theater (video + custom controls + prev/next)
    private func theater(_ clip: LocalClip) -> some View {
        ZStack {
            Color.black
            PlayerView(player: pc.player, controls: .none)
                .onTapGesture { pc.toggle() }

            // prev / next
            HStack {
                navArrow("chevron.left", enabled: (index ?? 0) < library.clips.count - 1) { step(1) }
                Spacer()
                navArrow("chevron.right", enabled: (index ?? 0) > 0) { step(-1) }
            }
            .padding(.horizontal, 14)

            // bottom control bar
            VStack {
                Spacer()
                controlBar
                    .padding(14)
                    .background(LinearGradient(colors: [.clear, .black.opacity(0.7)],
                                               startPoint: .top, endPoint: .bottom))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.R.lg))
        .padding(.horizontal, 22)
        .frame(maxHeight: .infinity)
    }

    private var controlBar: some View {
        HStack(spacing: 14) {
            Button { pc.toggle() } label: {
                Image(systemName: pc.playing ? "pause.fill" : "play.fill")
                    .font(.system(size: 16, weight: .bold)).foregroundStyle(.white).frame(width: 22)
            }.buttonStyle(.plain)
            Text(PlayerController.fmt(pc.current)).font(Theme.ui(12)).foregroundStyle(.white).monospacedDigit()
            Seeker(current: pc.current, duration: pc.duration) { pc.seek(to: $0) }
            Text(PlayerController.fmt(pc.duration)).font(Theme.ui(12)).foregroundStyle(.white.opacity(0.7)).monospacedDigit()
        }
    }

    private func navArrow(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Circle().fill(.black.opacity(0.4)))
                .overlay(Circle().stroke(.white.opacity(0.15)))
        }
        .buttonStyle(.plain).opacity(enabled ? 1 : 0.25).disabled(!enabled)
    }

    // MARK: Info panel
    private func infoPanel(_ clip: LocalClip) -> some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Text(clip.game ?? "Untitled clip").font(Theme.display(22)).foregroundStyle(Theme.text)
                HStack(spacing: 18) {
                    metaItem("calendar", clip.createdAt.formatted(date: .abbreviated, time: .shortened))
                    metaItem("person.fill", "You")
                    metaItem("eye.fill", clip.views.map { "\($0) views" } ?? (clip.link != nil ? "0 views" : "—"))
                    metaItem("gamecontroller.fill", clip.game ?? "Unknown")
                }
                // description
                TextField("Add a description…", text: $descDraft, axis: .vertical)
                    .textFieldStyle(.plain).font(Theme.ui(13)).foregroundStyle(Theme.text)
                    .lineLimit(1...3)
                    .padding(10)
                    .background(Theme.card)
                    .overlay(RoundedRectangle(cornerRadius: Theme.R.sm).stroke(Theme.stroke))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.R.sm))
                    .onSubmit { if let id = clip.id as String? { library.setDescription(id, descDraft) } }
            }
            Spacer()
        }
        .padding(22)
        .frame(height: 190)
    }

    private func metaItem(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 11)).foregroundStyle(Theme.primaryHi)
            Text(text).font(Theme.ui(12)).foregroundStyle(Theme.textDim)
        }
    }

    // MARK: Share
    private func shareButton(_ clip: LocalClip) -> some View {
        Group {
            if let link = clip.link {
                Button { copyLink(link) } label: {
                    Label(linkState == .copied ? "Copied" : "Copy link",
                          systemImage: linkState == .copied ? "checkmark" : "link").frame(minWidth: 90)
                }.buttonStyle(TailButtonStyle(kind: linkState == .copied ? .primary : .action))
            } else {
                Button {
                    linkState = .creating
                    Task {
                        let made = await model.createLink(for: clip)
                        if let made { copyLink(made) } else { linkState = .idle }
                    }
                } label: {
                    Label(linkState == .creating ? "Creating…" : "Create link", systemImage: "link.badge.plus")
                        .frame(minWidth: 90)
                }.buttonStyle(TailButtonStyle(kind: .action)).disabled(linkState == .creating)
            }
        }
    }

    // MARK: Actions
    private func reload() {
        guard let clip else { return }
        pc.load(library.url(for: clip))
        descDraft = clip.desc ?? ""
        linkState = .idle
        if clip.link != nil { Task { await model.refreshViews(for: clip) } }
    }

    private func step(_ delta: Int) {
        guard let i = index else { return }
        let n = i + delta
        if library.clips.indices.contains(n) { index = n }
    }

    private func copyLink(_ s: String) {
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(s, forType: .string)
        linkState = .copied
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { if linkState == .copied { linkState = .idle } }
    }
}

// Custom draggable seeker.
private struct Seeker: View {
    let current: Double
    let duration: Double
    let onScrub: (Double) -> Void
    @State private var dragging = false
    @State private var dragFrac: Double = 0

    var body: some View {
        GeometryReader { geo in
            let frac = dragging ? dragFrac : (duration > 0 ? min(max(current / duration, 0), 1) : 0)
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.2)).frame(height: 5)
                Capsule().fill(Theme.orangeGrad).frame(width: geo.size.width * frac, height: 5)
                Circle().fill(.white).frame(width: dragging ? 14 : 11, height: dragging ? 14 : 11)
                    .shadow(radius: 3)
                    .offset(x: geo.size.width * frac - (dragging ? 7 : 5.5))
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { v in
                    dragging = true
                    dragFrac = min(max(v.location.x / geo.size.width, 0), 1)
                }
                .onEnded { _ in
                    if duration > 0 { onScrub(dragFrac * duration) }
                    dragging = false
                })
        }
        .frame(height: 18)
    }
}
