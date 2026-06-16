import SwiftUI
import AppKit

// Folders tab: boxes for each folder; open one to see the clips inside.
struct FoldersView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var library: LocalLibrary
    @State private var open: String?
    @State private var index: Int?
    @State private var newFolder = false
    @State private var newName = ""

    private let cols = [GridItem(.adaptive(minimum: 220, maximum: 300), spacing: 18)]
    private var inOpen: [LocalClip] { open.map { library.clips(in: $0) } ?? [] }

    var body: some View {
        if let folder = open {
            if index != nil {
                ClipViewer(model: model, library: library, clips: inOpen, index: $index,
                           onExit: { index = nil })
            } else {
                folderDetail(folder)
            }
        } else {
            foldersGrid
        }
    }

    // MARK: Folder grid
    private var foldersGrid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("FOLDERS").font(Theme.display(30)).foregroundStyle(Theme.text)
                    Spacer()
                    Button { newFolder = true } label: {
                        HStack(spacing: 6) { Image(systemName: "plus"); Text("New folder") }
                    }.buttonStyle(TailButtonStyle(kind: .primary))
                    .popover(isPresented: $newFolder) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("New folder").font(Theme.ui(13, .semibold)).foregroundStyle(Theme.text)
                            TextField("Name", text: $newName).textFieldStyle(.roundedBorder).frame(width: 180)
                                .onSubmit(addFolder)
                            Button("Create") { addFolder() }.buttonStyle(TailButtonStyle(kind: .primary))
                        }.padding(14).background(Theme.surface)
                    }
                }
                if library.folders.isEmpty {
                    empty.frame(maxWidth: .infinity, minHeight: 280)
                } else {
                    LazyVGrid(cols: cols) {
                        ForEach(library.folders, id: \.self) { f in
                            FolderBox(library: library, name: f,
                                      count: library.clips(in: f).count,
                                      onOpen: { open = f },
                                      onDelete: { library.deleteFolder(f) })
                        }
                    }
                }
            }.padding(28)
        }
    }

    // MARK: Folder detail (clips inside)
    private func folderDetail(_ folder: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    Button { open = nil } label: {
                        HStack(spacing: 6) { Image(systemName: "chevron.left"); Text("Folders") }
                    }.buttonStyle(TailButtonStyle(kind: .ghost))
                    Text(folder).font(Theme.display(26)).foregroundStyle(Theme.text)
                    Text("\(inOpen.count)").font(Theme.ui(13, .semibold)).foregroundStyle(Theme.primaryHi)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Capsule().fill(Theme.primary.opacity(0.18)))
                    Spacer()
                }
                if inOpen.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "folder").font(.system(size: 34)).foregroundStyle(Theme.textFaint)
                        Text("Empty folder").font(Theme.display(18)).foregroundStyle(Theme.text)
                        Text("Add clips from the … menu on a clip card.")
                            .font(Theme.ui(13)).foregroundStyle(Theme.textDim)
                    }.frame(maxWidth: .infinity, minHeight: 260)
                } else {
                    LazyVGrid(cols: [GridItem(.adaptive(minimum: 280, maximum: 360), spacing: 18)]) {
                        ForEach(Array(inOpen.enumerated()), id: \.element.id) { pair in
                            ClipCard(model: model, library: library, clip: pair.element)
                                .onTapGesture { index = pair.offset }
                        }
                    }
                }
            }.padding(28)
        }
    }

    private func addFolder() {
        let n = newName.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return }
        library.createFolder(n); newName = ""; newFolder = false
    }

    private var empty: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(Theme.primary.opacity(0.14)).frame(width: 88, height: 88)
                Image(systemName: "folder.fill").font(.system(size: 32)).foregroundStyle(Theme.primaryHi)
            }
            Text("NO FOLDERS").font(Theme.display(22)).foregroundStyle(Theme.text)
            Text("Make a folder, then add clips to it from the … menu on a clip.")
                .font(Theme.ui(13)).foregroundStyle(Theme.textDim)
        }
    }
}

// Helper so LazyVGrid columns read cleanly.
private extension LazyVGrid {
    init(cols: [GridItem], @ViewBuilder content: () -> Content) {
        self.init(columns: cols, spacing: 18, content: content)
    }
}

private struct FolderBox: View {
    @ObservedObject var library: LocalLibrary
    let name: String
    let count: Int
    let onOpen: () -> Void
    let onDelete: () -> Void
    @State private var cover: NSImage?
    @State private var hover = false

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    Rectangle().fill(Theme.elevated)
                    if let cover {
                        Image(nsImage: cover).resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Image(systemName: "folder.fill").font(.system(size: 40)).foregroundStyle(Theme.primaryHi.opacity(0.7))
                    }
                    LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
                    VStack { HStack { Spacer()
                        Menu {
                            Button("Delete folder", role: .destructive, action: onDelete)
                        } label: {
                            Image(systemName: "ellipsis").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                                .frame(width: 26, height: 26).background(.black.opacity(0.45), in: Circle())
                        }.menuStyle(.borderlessButton).fixedSize().menuIndicator(.hidden).opacity(hover ? 1 : 0)
                    }; Spacer() }.padding(7)
                }
                .frame(height: 130).clipped()
                HStack {
                    Image(systemName: "folder.fill").font(.system(size: 12)).foregroundStyle(Theme.primaryHi)
                    Text(name).font(Theme.ui(14, .semibold)).foregroundStyle(Theme.text).lineLimit(1)
                    Spacer()
                    Text("\(count)").font(Theme.ui(12)).foregroundStyle(Theme.textDim)
                }.padding(12).background(Theme.card)
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.R.lg))
            .overlay(RoundedRectangle(cornerRadius: Theme.R.lg).stroke(hover ? Theme.primary.opacity(0.5) : Theme.stroke))
            .shadow(color: (hover ? Theme.primary : .black).opacity(hover ? 0.4 : 0.25), radius: hover ? 16 : 7, y: 5)
            .scaleEffect(hover ? 1.015 : 1)
            .animation(.easeOut(duration: 0.15), value: hover)
        }
        .buttonStyle(.plain).onHover { hover = $0 }
        .task(id: name) {
            if let first = library.clips(in: name).first { cover = await library.thumbnail(for: first) }
        }
    }
}
