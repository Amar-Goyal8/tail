import AppKit
import SwiftUI
import AVKit
import Supabase
import Carbon.HIToolbox

// Captures a keystroke and reports it as a Carbon hotkey (keyCode + modifiers).
struct HotkeyRecorder: View {
    @ObservedObject var model: AppModel
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        Button {
            if recording { stop() } else { start() }
        } label: {
            HStack {
                Image(systemName: recording ? "circle.fill" : "keyboard")
                    .foregroundStyle(recording ? Theme.live : Theme.textDim).font(.system(size: 11))
                Text(recording ? "Press keys…" : model.hotkeyLabel).font(Theme.ui(13, .semibold))
                Spacer()
            }
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.R.sm))
            .overlay(RoundedRectangle(cornerRadius: Theme.R.sm).stroke(recording ? Theme.live.opacity(0.6) : Theme.stroke))
        }.buttonStyle(.plain)
    }

    private func start() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { e in
            handle(e); return nil
        }
    }
    private func stop() {
        recording = false
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }
    private func handle(_ e: NSEvent) {
        let mods = e.modifierFlags
        var carbon: UInt32 = 0; var label = ""
        if mods.contains(.control) { carbon |= UInt32(controlKey); label += "⌃" }
        if mods.contains(.option)  { carbon |= UInt32(optionKey);  label += "⌥" }
        if mods.contains(.shift)   { carbon |= UInt32(shiftKey);   label += "⇧" }
        if mods.contains(.command) { carbon |= UInt32(cmdKey);     label += "⌘" }
        let key = (e.charactersIgnoringModifiers ?? "").uppercased()
        label += key.isEmpty ? "?" : key
        model.onSetHotkey(UInt32(e.keyCode), carbon, label)
        stop()
    }
}

// Custom gaming-styled main window: hand-built sidebar + content, no stock chrome.
struct MainWindowView: View {
    @ObservedObject var model: AppModel
    @State private var tab: Tab = .clips
    enum Tab: String, CaseIterable, Identifiable {
        case clips = "Clips", folders = "Folders", account = "Account"
        var id: String { rawValue }
        var icon: String {
            switch self { case .clips: "square.grid.2x2.fill"; case .folders: "folder.fill"; case .account: "person.fill" }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            Sidebar(model: model, tab: $tab)
            ZStack {
                Theme.bgGrad.ignoresSafeArea()
                if model.showSettings {
                    TailSettingsView(model: model, onClose: { model.showSettings = false })
                } else {
                    VStack(spacing: 0) {
                        TopBar(model: model)
                        Group {
                            switch tab {
                            case .clips: ClipsPane(model: model)
                            case .folders: FoldersPane(model: model)
                            case .account: AccountPane(model: model)
                            }
                        }
                    }
                }
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .background(Theme.bg)
        .preferredColorScheme(.dark)
    }
}

// Top status/control bar: detected game · clip button · buffer+hotkey pill · gear.
private struct TopBar: View {
    @ObservedObject var model: AppModel
    @State private var showQuick = false

    var body: some View {
        HStack(spacing: 12) {
            // Detected game (or waiting)
            HStack(spacing: 9) {
                Group {
                    if let icon = model.gameIcon {
                        Image(nsImage: icon).resizable().frame(width: 22, height: 22)
                    } else {
                        Image(systemName: "gamecontroller").foregroundStyle(Theme.textFaint)
                    }
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text(model.gameActive ? "ARMED" : "IDLE").font(Theme.mono(9, .medium)).tracking(2)
                        .foregroundStyle(model.gameActive ? Theme.accent : Theme.textFaint)
                    Text(model.gameName).font(Theme.ui(13, .semibold))
                        .foregroundStyle(model.gameActive ? Theme.text : Theme.textDim).lineLimit(1)
                }
            }
            Spacer()
            Button(action: model.onClip) {
                HStack(spacing: 6) { Image(systemName: "scissors"); Text("Clip") }
            }.buttonStyle(TailButtonStyle(kind: .action))

            // Buffer + hotkey pill -> quick edit popover
            Button { showQuick.toggle() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath").font(.system(size: 11))
                    Text("\(model.bufferSeconds)s").font(Theme.ui(12, .semibold))
                    Text(model.hotkeyLabel).font(Theme.ui(11)).foregroundStyle(Theme.textDim)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(Color.white.opacity(0.07)))
                }
                .foregroundStyle(Theme.text)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Theme.elevated, in: Capsule())
                .overlay(Capsule().stroke(Theme.stroke))
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showQuick, arrowEdge: .bottom) {
                QuickSettings(model: model).padding(16).frame(width: 240)
                    .background(Theme.surface)
            }

            Button(action: model.onOpenSettings) {
                Image(systemName: "gearshape.fill").font(.system(size: 15))
                    .foregroundStyle(Theme.textDim).frame(width: 34, height: 34)
                    .background(Theme.elevated, in: Circle()).overlay(Circle().stroke(Theme.stroke))
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 22).padding(.vertical, 14)
        .background(Theme.surface.opacity(0.6))
        .overlay(Rectangle().fill(Theme.stroke).frame(height: 1), alignment: .bottom)
    }
}

private struct QuickSettings: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("CLIP LENGTH").font(Theme.ui(10, .semibold)).tracking(1.5).foregroundStyle(Theme.textDim)
            HStack {
                ForEach([15, 30, 60, 90], id: \.self) { s in
                    Button("\(s)s") { model.onSetBuffer(s) }
                        .buttonStyle(TailButtonStyle(kind: model.bufferSeconds == s ? .primary : .ghost))
                }
            }
            Divider().overlay(Theme.stroke)
            Text("HOTKEY").font(Theme.ui(10, .semibold)).tracking(1.5).foregroundStyle(Theme.textDim)
            HotkeyRecorder(model: model)
        }
    }
}

private struct Sidebar: View {
    @ObservedObject var model: AppModel
    @Binding var tab: MainWindowView.Tab

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Wordmark
            HStack(spacing: 11) {
                ReticleMark(size: 32)
                Text("TAIL").font(Theme.display(20)).foregroundStyle(Theme.text).tracking(3)
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
                    .font(Theme.mono(11, .medium)).tracking(1.5).foregroundStyle(Theme.textDim)
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

struct PresetRow: View {
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

struct TailToggle: View {
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

private struct FoldersPane: View {
    @ObservedObject var model: AppModel
    var body: some View {
        if let library = model.library {
            FoldersView(model: model, library: library)
        } else {
            Text("Loading…").font(Theme.ui(14)).foregroundStyle(Theme.textDim)
        }
    }
}

private struct AccountPane: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var auth = AuthManager.shared
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
                    Text("SIGNED IN AS").font(Theme.mono(11, .medium)).tracking(1.5).foregroundStyle(Theme.textDim)
                    HStack {
                        Text(auth.email ?? "—").font(Theme.ui(13)).foregroundStyle(Theme.text)
                        Spacer()
                        Button("Sign out") { auth.signOut() }.buttonStyle(TailButtonStyle(kind: .ghost))
                    }
                }.panel(18)

                VStack(alignment: .leading, spacing: 12) {
                    Text("CONNECTIONS").font(Theme.mono(11, .medium)).tracking(1.5).foregroundStyle(Theme.textDim)
                    connectionRow("Discord", icon: "bubble.left.fill", key: "discord", provider: .discord)
                    connectionRow("Google", icon: "globe", key: "google", provider: .google)
                }.panel(18)
            }
            .padding(28).frame(maxWidth: 560, alignment: .leading).frame(maxWidth: .infinity, alignment: .leading)
        }
        .task { await auth.loadIdentities() }
    }

    @ViewBuilder
    private func connectionRow(_ name: String, icon: String, key: String, provider: Provider) -> some View {
        let linked = auth.linkedProviders.contains(key)
        HStack(spacing: 11) {
            Image(systemName: icon).font(.system(size: 14)).foregroundStyle(linked ? Theme.accent : Theme.textDim)
                .frame(width: 20)
            Text(name).font(Theme.ui(13, .medium)).foregroundStyle(Theme.text)
            Spacer()
            if linked {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
                    Text("Connected").font(Theme.ui(12)).foregroundStyle(Theme.textDim)
                    if auth.identities.count > 1, let id = auth.identities.first(where: { $0.provider == key }) {
                        Button("Unlink") { Task { try? await auth.unlink(id) } }
                            .buttonStyle(.plain).font(Theme.ui(11)).foregroundStyle(Theme.live)
                    }
                }
            } else {
                Button("Link") { Task { try? await auth.link(provider) } }
                    .buttonStyle(TailButtonStyle(kind: .ghost))
            }
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
        win.backgroundColor = NSColor(red: 0.031, green: 0.035, blue: 0.04, alpha: 1)
        win.contentViewController = NSHostingController(rootView: RootView(model: model))
        win.center(); win.isReleasedWhenClosed = false
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
        window = win
    }
}
