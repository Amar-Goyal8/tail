import AppKit
import Carbon.HIToolbox

// Menu-bar app. Lives in tray. Hotkey F9 -> flush replay buffer to .mp4.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var config = Config.p1440_120
    private var buffer: ReplayBuffer!
    private var encoder: Encoder!
    private var capture: CaptureEngine!
    private var hotKey: HotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenu()
        buffer = ReplayBuffer(seconds: config.bufferSeconds)
        encoder = Encoder(config: config) { [weak self] sample in
            self?.buffer.append(sample)
        }
        capture = CaptureEngine(config: config, encoder: encoder)
        startCapture()
        installHotkey()
    }

    private func setupMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "🎬"
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Clip last \(config.bufferSeconds)s (⌃⌥C)",
                                action: #selector(clip), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func startCapture() {
        let capture = self.capture!
        Task { @MainActor in
            do { try await capture.start() }
            catch { self.log("capture start failed: \(error.localizedDescription)") }
        }
    }

    @objc private func clip() {
        let buffer = self.buffer!
        let dir = config.saveDir
        Task.detached {
            if let url = buffer.flush(to: dir) {
                await self.notify("Clip saved", url.lastPathComponent)
            } else {
                await self.log("flush failed (buffer empty or no keyframe yet)")
            }
        }
    }

    private func notify(_ title: String, _ body: String) {
        log("saved \(body)")
        let n = NSUserNotification()
        n.title = title
        n.informativeText = body
        NSUserNotificationCenter.default.deliver(n)
    }

    @objc private func quit() { NSApp.terminate(nil) }

    // Global ⌃⌥C via Carbon hotkey. No TCC permission needed.
    private func installHotkey() {
        let control = UInt32(controlKey)
        let option = UInt32(optionKey)
        hotKey = HotKey(keyCode: 8, modifiers: control | option) { [weak self] in
            Task { @MainActor in
                self?.log("hotkey fired")
                self?.clip()
            }
        }
        log("hotkey registered ⌃⌥C")
    }

    private func log(_ s: String) {
        FileHandle.standardError.write("[tail] \(s)\n".data(using: .utf8)!)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // menu-bar only, no dock icon
app.run()
