import AppKit
import SwiftUI
import AVKit

// Custom gaming-styled main window: hand-built sidebar + content, no stock chrome.
struct MainWindowView: View {
    @ObservedObject var model: AppModel
    @State private var tab: Tab = .clips
    enum Tab: String, CaseIterable, Identifiable {
        case record = "Record", clips = "Clips", account = "Account"
        var id: String { rawValue }
        var icon: String { self == .record ? "dot.radiowaves.left.and.right" : self == .clips ? "square.grid.2x2.fill" : "person.fill" }
    }

    var body: some View {
        HStack(spacing: 0) {
            Sidebar(model: model, tab: $tab)
            ZStack {
                Theme.bgGrad.ignoresSafeArea()
                Group {
                    switch tab {
                    case .record: RecordPane(model: model)
                    case .clips: ClipsPane(model: model)
                    case .account: AccountPane(model: model)
                    }
                }
            }
        }
        .frame(minWidth: 880, minHeight: 580)
        .background(Theme.bg)
        .preferredColorScheme(.dark)
    }
}

private struct Sidebar: View {
    @ObservedObject var model: AppModel
    @Binding var tab: MainWindowView.Tab

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Wordmark
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9).fill(Theme.violetGrad).frame(width: 30, height: 30)
                    Image(systemName: "play.fill").font(.system(size: 13, weight: .black)).foregroundStyle(.white)
                }
                Text("TAIL").font(Theme.display(20)).foregroundStyle(Theme.text).tracking(1)
            }
            .padding(.horizontal, 16).padding(.top, 22).padding(.bottom, 18)

            ForEach(MainWindowView.Tab.allCases) { t in
                NavItem(tab: t, active: tab == t) { tab = t }
            }

            Spacer()

            // Plan chip
            HStack(spacing: 8) {
                Circle().fill(model.plan == "pro" ? Theme.success : Theme.textFaint).frame(width: 7, height: 7)
                Text(model.plan == "pro" ? "TAIL PRO" : "FREE PLAN")
                    .font(Theme.ui(11, .semibold)).tracking(1).foregroundStyle(Theme.textDim)
            }
            .padding(.horizontal, 18).padding(.bottom, 18)
        }
        .frame(width: 186)
        .background(Theme.surface)
        .overlay(Rectangle().fill(Theme.stroke).frame(width: 1), alignment: .trailing)
    }
}

private struct NavItem: View {
    let tab: MainWindowView.Tab
    let active: Bool
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: tab.icon).font(.system(size: 14, weight: .semibold))
                    .frame(width: 18)
                Text(tab.rawValue).font(Theme.ui(14, .medium))
                Spacer()
            }
            .foregroundStyle(active ? Theme.text : (hover ? Theme.text : Theme.textDim))
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background {
                if active {
                    RoundedRectangle(cornerRadius: 10).fill(Theme.primary.opacity(0.18))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.primary.opacity(0.5)))
                } else if hover {
                    RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04))
                }
            }
            .overlay(alignment: .leading) {
                if active { RoundedRectangle(cornerRadius: 2).fill(Theme.primaryHi).frame(width: 3, height: 16).offset(x: -2) }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .onHover { hover = $0 }
    }
}

private struct PaneTitle: View {
    let text: String, sub: String
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(text).font(Theme.display(30)).foregroundStyle(Theme.text)
            Text(sub).font(Theme.ui(13)).foregroundStyle(Theme.textDim)
        }
    }
}

private struct RecordPane: View {
    @ObservedObject var model: AppModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PaneTitle(text: "RECORD", sub: "Press ⌃⌥C anywhere to grab the last 30 seconds")

                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Circle().fill(Theme.success).frame(width: 8, height: 8)
                            .shadow(color: Theme.success, radius: 5)
                        Text(model.statusText.uppercased()).font(Theme.ui(11, .semibold)).tracking(1)
                            .foregroundStyle(Theme.textDim)
                        Spacer()
                        Label(model.sourceLabel, systemImage: "display")
                            .font(Theme.ui(12)).foregroundStyle(Theme.textDim)
                    }
                    Button(action: model.onClip) {
                        HStack { Image(systemName: "scissors"); Text("CLIP LAST 30s").tracking(1); Spacer()
                            Text("⌃⌥C").font(Theme.ui(12)).opacity(0.8) }
                    }.buttonStyle(TailButtonStyle(kind: .action, full: true))
                    Button(action: model.onTrimLast) {
                        HStack { Image(systemName: "timeline.selection"); Text("Trim & share last clip"); Spacer() }
                    }.buttonStyle(TailButtonStyle(kind: .ghost, full: true))
                }.panel(18)

                VStack(alignment: .leading, spacing: 12) {
                    Text("QUALITY").font(Theme.ui(12, .semibold)).tracking(1.5).foregroundStyle(Theme.textDim)
                    ForEach(Config.presets, id: \.name) { p in
                        PresetRow(name: p.name, selected: model.presetName == p.name,
                                  locked: p.pro && model.plan != "pro") { model.onPickPreset(p.name) }
                    }
                }.panel(18)

                VStack(alignment: .leading, spacing: 12) {
                    Text("AUDIO").font(Theme.ui(12, .semibold)).tracking(1.5).foregroundStyle(Theme.textDim)
                    TailToggle(label: "Capture microphone", on: model.micEnabled) { model.micEnabled = $0; model.onToggleMic($0) }
                    Button(action: model.onOpenClipsFolder) {
                        HStack { Image(systemName: "folder"); Text("Open clips folder"); Spacer() }
                    }.buttonStyle(TailButtonStyle(kind: .ghost, full: true))
                }.panel(18)
            }
            .padding(28)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct PresetRow: View {
    let name: String, selected: Bool, locked: Bool
    let action: () -> Void
    @State private var hover = false
    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                ZStack {
                    Circle().stroke(selected ? Theme.primaryHi : Theme.strokeHi, lineWidth: 2).frame(width: 17, height: 17)
                    if selected { Circle().fill(Theme.primaryHi).frame(width: 9, height: 9) }
                }
                Text(name).font(Theme.ui(14, selected ? .semibold : .regular)).foregroundStyle(Theme.text)
                if locked { Image(systemName: "lock.fill").font(.system(size: 10)).foregroundStyle(Theme.accent) }
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 11)
                .fill(selected ? Theme.primary.opacity(0.12) : (hover ? Color.white.opacity(0.03) : .clear)))
            .overlay(RoundedRectangle(cornerRadius: 11).stroke(selected ? Theme.primary.opacity(0.4) : .clear))
        }
        .buttonStyle(.plain).onHover { hover = $0 }
    }
}

private struct TailToggle: View {
    let label: String; let on: Bool; let set: (Bool) -> Void
    var body: some View {
        Button { set(!on) } label: {
            HStack {
                Text(label).font(Theme.ui(14)).foregroundStyle(Theme.text)
                Spacer()
                ZStack(alignment: on ? .trailing : .leading) {
                    Capsule().fill(on ? AnyShapeStyle(Theme.violetGrad) : AnyShapeStyle(Theme.elevated))
                        .frame(width: 40, height: 23)
                    Circle().fill(.white).frame(width: 18, height: 18).padding(2)
                }
            }
        }.buttonStyle(.plain)
    }
}

private struct ClipsPane: View {
    @ObservedObject var model: AppModel
    var body: some View {
        if let library = model.library {
            ClipLibraryView(model: model, library: library)
        } else {
            Text("Loading…").font(Theme.ui(14)).foregroundStyle(Theme.textDim)
        }
    }
}

private struct AccountPane: View {
    @ObservedObject var model: AppModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PaneTitle(text: "ACCOUNT", sub: "Your plan and identity")

                ZStack(alignment: .topLeading) {
                    (model.plan == "pro" ? AnyView(Theme.violetGrad) : AnyView(Theme.card))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.R.lg))
                        .overlay(RoundedRectangle(cornerRadius: Theme.R.lg).stroke(Theme.stroke))
                    VStack(alignment: .leading, spacing: 14) {
                        Text(model.plan == "pro" ? "TAIL PRO" : "FREE")
                            .font(Theme.display(26)).foregroundStyle(.white)
                        Text(model.plan == "pro" ? "4K capture + higher bitrates unlocked."
                                                  : "Upgrade for 4K capture and higher bitrates.")
                            .font(Theme.ui(13)).foregroundStyle(model.plan == "pro" ? .white.opacity(0.85) : Theme.textDim)
                        if model.plan != "pro" {
                            Button(action: model.onUpgrade) {
                                HStack { Image(systemName: "bolt.fill"); Text("UPGRADE TO PRO").tracking(1) }
                            }.buttonStyle(TailButtonStyle(kind: .action)).padding(.top, 4)
                        }
                    }.padding(20)
                }.frame(height: 170)

                VStack(alignment: .leading, spacing: 10) {
                    Text("ACCOUNT ID").font(Theme.ui(12, .semibold)).tracking(1.5).foregroundStyle(Theme.textDim)
                    HStack {
                        Text(String(Account.token.prefix(22)) + "…").font(Theme.ui(12)).foregroundStyle(Theme.text)
                        Spacer()
                        Button("Copy") {
                            NSPasteboard.general.clearContents(); NSPasteboard.general.setString(Account.token, forType: .string)
                        }.buttonStyle(TailButtonStyle(kind: .ghost))
                    }
                }.panel(18)
            }
            .padding(28).frame(maxWidth: 560, alignment: .leading).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

@MainActor
final class MainWindowController {
    private var window: NSWindow?
    func show(model: AppModel) {
        if let window { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 940, height: 620),
                           styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                           backing: .buffered, defer: false)
        win.title = "Tail"
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.backgroundColor = NSColor(red: 0.043, green: 0.043, blue: 0.07, alpha: 1)
        win.contentViewController = NSHostingController(rootView: MainWindowView(model: model))
        win.center(); win.isReleasedWhenClosed = false
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
        window = win
    }
}
