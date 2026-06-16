import AppKit
import SwiftUI
import AVKit

// The main Tail app window: a sidebar with Record / Clips / Account.
struct MainWindowView: View {
    @ObservedObject var model: AppModel
    @State private var tab: Tab = .record
    enum Tab: String, CaseIterable, Identifiable { case record = "Record", clips = "Clips", account = "Account"; var id: String { rawValue } }

    var body: some View {
        NavigationSplitView {
            List(Tab.allCases, selection: $tab) { t in
                Label(t.rawValue, systemImage: icon(t)).tag(t)
            }
            .navigationSplitViewColumnWidth(170)
            .listStyle(.sidebar)
        } detail: {
            switch tab {
            case .record: RecordPane(model: model)
            case .clips: ClipsPane(model: model)
            case .account: AccountPane(model: model)
            }
        }
        .frame(minWidth: 760, minHeight: 520)
    }

    private func icon(_ t: Tab) -> String {
        switch t { case .record: "record.circle"; case .clips: "film.stack"; case .account: "person.crop.circle" }
    }
}

private struct RecordPane: View {
    @ObservedObject var model: AppModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Record").font(.largeTitle.bold())

                GroupBox {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Circle().fill(.green).frame(width: 9, height: 9)
                            Text(model.statusText).foregroundStyle(.secondary)
                            Spacer()
                            Text("Source: \(model.sourceLabel)").font(.caption).foregroundStyle(.secondary)
                        }
                        Button {
                            model.onClip()
                        } label: {
                            Label("Clip last 30s  ·  ⌃⌥C", systemImage: "scissors")
                                .frame(maxWidth: .infinity).padding(.vertical, 6)
                        }
                        .buttonStyle(.borderedProminent).controlSize(.large)
                        Button { model.onTrimLast() } label: {
                            Label("Trim & share last clip", systemImage: "timeline.selection")
                        }
                    }.padding(6)
                }

                GroupBox("Quality") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Config.presets, id: \.name) { p in
                            let locked = p.pro && model.plan != "pro"
                            HStack {
                                Image(systemName: model.presetName == p.name ? "largecircle.fill.circle" : "circle")
                                    .foregroundStyle(model.presetName == p.name ? Color.accentColor : .secondary)
                                Text(p.name)
                                if locked { Image(systemName: "lock.fill").font(.caption).foregroundStyle(.secondary) }
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { model.onPickPreset(p.name) }
                        }
                    }.padding(6)
                }

                GroupBox("Audio & sharing") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Capture microphone", isOn: Binding(
                            get: { model.micEnabled }, set: { model.micEnabled = $0; model.onToggleMic($0) }))
                        Toggle("Upload + copy link on clip", isOn: Binding(
                            get: { model.uploadOnClip }, set: { model.uploadOnClip = $0; model.onToggleUpload($0) }))
                        Button("Open clips folder") { model.onOpenClipsFolder() }
                        if let link = model.lastLink {
                            HStack {
                                Text(link).font(.caption).monospaced().lineLimit(1).truncationMode(.middle)
                                Button("Copy") {
                                    NSPasteboard.general.clearContents(); NSPasteboard.general.setString(link, forType: .string)
                                }.font(.caption)
                            }
                        }
                    }.padding(6)
                }
            }
            .padding(24)
        }
    }
}

private struct ClipsPane: View {
    @ObservedObject var model: AppModel
    var body: some View {
        if let client = model.clipsClient {
            LibraryView(client: client)
        } else {
            Text("No backend configured").foregroundStyle(.secondary)
        }
    }
}

private struct AccountPane: View {
    @ObservedObject var model: AppModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Account").font(.largeTitle.bold())
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Plan").foregroundStyle(.secondary); Spacer()
                            Text(model.plan == "pro" ? "Tail Pro" : "Free")
                                .bold().foregroundStyle(model.plan == "pro" ? .green : .primary)
                        }
                        if model.plan != "pro" {
                            Button {
                                model.onUpgrade()
                            } label: {
                                Label("Upgrade to Pro · unlock 4K", systemImage: "sparkles")
                                    .frame(maxWidth: .infinity).padding(.vertical, 4)
                            }.buttonStyle(.borderedProminent)
                        }
                        HStack {
                            Text("Account ID").foregroundStyle(.secondary); Spacer()
                            Text(String(Account.token.prefix(16)) + "…").font(.caption).monospaced()
                            Button("Copy") {
                                NSPasteboard.general.clearContents(); NSPasteboard.general.setString(Account.token, forType: .string)
                            }.font(.caption)
                        }
                    }.padding(6)
                }
            }.padding(24)
        }
    }
}

@MainActor
final class MainWindowController {
    private var window: NSWindow?
    func show(model: AppModel) {
        if let window { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 820, height: 560),
                           styleMask: [.titled, .closable, .miniaturizable, .resizable],
                           backing: .buffered, defer: false)
        win.title = "Tail"
        win.contentViewController = NSHostingController(rootView: MainWindowView(model: model))
        win.center(); win.isReleasedWhenClosed = false
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
        window = win
    }
}
