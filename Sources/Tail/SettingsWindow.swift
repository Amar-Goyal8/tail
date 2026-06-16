import AppKit
import SwiftUI

// Settings the app exposes. Values + actions are supplied by AppDelegate.
@MainActor
final class SettingsModel: ObservableObject {
    @Published var uploadOnClip: Bool
    @Published var bufferSeconds: Int
    let accountId: String
    let backendURL: String
    @Published var plan: String

    var onUploadChange: (Bool) -> Void = { _ in }
    var onBufferChange: (Int) -> Void = { _ in }
    var onOpenSaveFolder: () -> Void = {}

    init(uploadOnClip: Bool, bufferSeconds: Int, accountId: String, backendURL: String, plan: String) {
        self.uploadOnClip = uploadOnClip
        self.bufferSeconds = bufferSeconds
        self.accountId = accountId
        self.backendURL = backendURL
        self.plan = plan
    }
}

struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        Form {
            Section("Clipping") {
                Toggle("Upload + copy link on clip", isOn: Binding(
                    get: { model.uploadOnClip },
                    set: { model.uploadOnClip = $0; model.onUploadChange($0) }))
                Stepper("Replay buffer: \(model.bufferSeconds)s", value: Binding(
                    get: { model.bufferSeconds },
                    set: { model.bufferSeconds = $0; model.onBufferChange($0) }), in: 10...120, step: 5)
                Button("Open clips folder") { model.onOpenSaveFolder() }
            }
            Section("Account") {
                LabeledContent("Plan", value: model.plan.capitalized)
                LabeledContent("Account ID") {
                    HStack {
                        Text(String(model.accountId.prefix(14)) + "…").font(.caption).monospaced()
                        Button("Copy") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(model.accountId, forType: .string)
                        }.font(.caption)
                    }
                }
                LabeledContent("Backend", value: model.backendURL)
            }
            Section {
                Text("Hotkey: ⌃⌥C clips the last \(model.bufferSeconds)s.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 360)
    }
}

@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    func show(model: SettingsModel) {
        if let window { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 360),
                           styleMask: [.titled, .closable], backing: .buffered, defer: false)
        win.title = "Tail — Settings"
        win.contentViewController = NSHostingController(rootView: SettingsView(model: model))
        win.center(); win.isReleasedWhenClosed = false
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
        window = win
    }
}
