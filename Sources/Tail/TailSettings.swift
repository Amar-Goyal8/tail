import AppKit
import SwiftUI

// Tabbed settings window (sidebar) — General / Video / Audio.
struct TailSettingsView: View {
    @ObservedObject var model: AppModel
    @State private var tab: STab = .video
    enum STab: String, CaseIterable, Identifiable {
        case video = "Video", audio = "Audio", general = "General"
        var id: String { rawValue }
        var icon: String { self == .video ? "4k.tv" : self == .audio ? "waveform" : "slider.horizontal.3" }
    }

    var body: some View {
        HStack(spacing: 0) {
            // sidebar
            VStack(alignment: .leading, spacing: 4) {
                Text("SETTINGS").font(Theme.ui(11, .semibold)).tracking(1.5)
                    .foregroundStyle(Theme.textFaint).padding(.horizontal, 14).padding(.top, 18).padding(.bottom, 10)
                ForEach(STab.allCases) { t in
                    Button { tab = t } label: {
                        HStack(spacing: 10) {
                            Image(systemName: t.icon).frame(width: 18).font(.system(size: 13))
                            Text(t.rawValue).font(Theme.ui(13, .medium)); Spacer()
                        }
                        .foregroundStyle(tab == t ? Theme.text : Theme.textDim)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(tab == t ? AnyShapeStyle(Theme.primary.opacity(0.18)) : AnyShapeStyle(.clear),
                                    in: RoundedRectangle(cornerRadius: 9))
                    }.buttonStyle(.plain).padding(.horizontal, 8)
                }
                Spacer()
            }
            .frame(width: 168).background(Theme.surface)
            .overlay(Rectangle().fill(Theme.stroke).frame(width: 1), alignment: .trailing)

            // content
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch tab {
                    case .video: video
                    case .audio: audio
                    case .general: general
                    }
                }.padding(24)
            }.frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.bg)
        }
        .frame(width: 660, height: 460)
        .preferredColorScheme(.dark)
    }

    // MARK: Video
    private var video: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Capture quality").font(Theme.display(20)).foregroundStyle(Theme.text)
            ForEach(Config.presets, id: \.name) { p in
                PresetRow(name: p.name, selected: model.presetName == p.name,
                          locked: p.pro && model.plan != "pro") {
                    if p.pro && model.plan != "pro" { model.onUpgrade() } else { model.onPickPreset(p.name) }
                }
            }
            Text("4K requires Tail Pro.").font(Theme.ui(11)).foregroundStyle(Theme.textFaint)
        }
    }

    // MARK: Audio
    private var audioMode: String {
        switch (model.systemAudio, model.micAudio) {
        case (true, true): return "Both"; case (true, false): return "Game"
        case (false, true): return "Voice"; default: return "Off"
        }
    }
    private func setMode(_ m: String) {
        let (sys, mic): (Bool, Bool)
        switch m { case "Both": (sys, mic) = (true, true); case "Game": (sys, mic) = (true, false)
                   case "Voice": (sys, mic) = (false, true); default: (sys, mic) = (false, false) }
        if model.systemAudio != sys { model.onSetSystemAudio(sys) }
        if model.micAudio != mic { model.onToggleMic(mic) }
    }
    private var audio: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Audio capture").font(Theme.display(20)).foregroundStyle(Theme.text)
            Text("WHAT TO RECORD").font(Theme.ui(10, .semibold)).tracking(1.5).foregroundStyle(Theme.textDim)
            HStack(spacing: 8) {
                ForEach(["Game", "Voice", "Both", "Off"], id: \.self) { m in
                    Button(m) { setMode(m) }
                        .buttonStyle(TailButtonStyle(kind: audioMode == m ? .primary : .ghost))
                }
            }
            Text("Game = desktop/game audio · Voice = your microphone · Both = mixed together.")
                .font(Theme.ui(11)).foregroundStyle(Theme.textFaint)
            Divider().overlay(Theme.stroke).padding(.vertical, 4)
            TailToggle(label: "Desktop / game audio", on: model.systemAudio) { model.onSetSystemAudio($0) }
            TailToggle(label: "Microphone", on: model.micAudio) { model.onToggleMic($0) }

            Divider().overlay(Theme.stroke).padding(.vertical, 4)
            Text("DEVICES").font(Theme.ui(10, .semibold)).tracking(1.5).foregroundStyle(Theme.textDim)
            deviceMenu(title: "Input (microphone)",
                       current: model.inputDevices.first { $0.id == model.selectedInput }?.name ?? "System default",
                       options: [("System default", nil)] + model.inputDevices.map { ($0.name, $0.id) }) {
                model.onSetInput($0)
            }
            deviceMenu(title: "Output (desktop audio)",
                       current: model.outputDevices.first { $0.id == model.selectedOutput }?.name ?? "System default",
                       options: model.outputDevices.map { ($0.name, $0.id) }) {
                if let uid = $0 { model.onSetOutput(uid) }
            }
            Text("Tail records the system's default output. Picking one sets it as default.")
                .font(Theme.ui(11)).foregroundStyle(Theme.textFaint)
        }
        .onAppear { model.refreshDevices() }
    }

    private func deviceMenu(title: String, current: String,
                            options: [(String, String?)], pick: @escaping (String?) -> Void) -> some View {
        HStack {
            Text(title).font(Theme.ui(13)).foregroundStyle(Theme.text)
            Spacer()
            Menu {
                ForEach(Array(options.enumerated()), id: \.offset) { _, opt in
                    Button(opt.0) { pick(opt.1) }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(current).font(Theme.ui(12, .medium)).lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 9))
                }
                .foregroundStyle(Theme.text)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.R.sm))
                .overlay(RoundedRectangle(cornerRadius: Theme.R.sm).stroke(Theme.stroke))
            }
            .menuStyle(.borderlessButton).fixedSize()
        }
    }

    // MARK: General
    private var general: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("General").font(Theme.display(20)).foregroundStyle(Theme.text)
            Text("CLIP LENGTH").font(Theme.ui(10, .semibold)).tracking(1.5).foregroundStyle(Theme.textDim)
            HStack(spacing: 8) {
                ForEach([15, 30, 60, 90, 120], id: \.self) { s in
                    Button("\(s)s") { model.onSetBuffer(s) }
                        .buttonStyle(TailButtonStyle(kind: model.bufferSeconds == s ? .primary : .ghost))
                }
            }
            Text("HOTKEY").font(Theme.ui(10, .semibold)).tracking(1.5).foregroundStyle(Theme.textDim).padding(.top, 4)
            HotkeyRecorder(model: model).frame(width: 220)
            Divider().overlay(Theme.stroke).padding(.vertical, 4)
            Button { model.onOpenClipsFolder() } label: {
                HStack { Image(systemName: "folder"); Text("Open clips folder") }
            }.buttonStyle(TailButtonStyle(kind: .ghost))
        }
    }
}

@MainActor
final class TailSettingsController {
    private var window: NSWindow?
    func show(model: AppModel) {
        if let window { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 660, height: 460),
                           styleMask: [.titled, .closable, .fullSizeContentView],
                           backing: .buffered, defer: false)
        win.title = "Tail Settings"; win.titlebarAppearsTransparent = true; win.titleVisibility = .hidden
        win.backgroundColor = NSColor(red: 0.043, green: 0.043, blue: 0.07, alpha: 1)
        win.contentViewController = NSHostingController(rootView: TailSettingsView(model: model))
        win.center(); win.isReleasedWhenClosed = false
        NSApp.activate(ignoringOtherApps: true); win.makeKeyAndOrderFront(nil)
        window = win
    }
}
