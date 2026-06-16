import AppKit
import Carbon.HIToolbox
import ScreenCaptureKit

// Menu-bar app. Lives in tray. Hotkey ⌃⌥C -> flush replay buffer to .mp4.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var config = Config.p1440_120
    private var buffer: ReplayBuffer!
    private var encoder: Encoder!
    private var capture: CaptureEngine!
    private var uploader: Uploader!
    private var hotKey: HotKey?
    private var currentSource: CaptureSource?
    private var lastClipURL: URL?
    private let trimController = TrimWindowController()
    private let libraryController = LibraryWindowController()
    private var clipsClient: ClipsClient!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenu()
        buffer = ReplayBuffer(seconds: config.bufferSeconds, config: config)
        encoder = Encoder(config: config) { [weak self] sample in
            self?.buffer.append(sample)
        }
        capture = CaptureEngine(config: config, encoder: encoder, buffer: buffer)
        uploader = Uploader(baseURL: config.backendURL)
        clipsClient = ClipsClient(baseURL: config.backendURL)
        startCapture(source: nil)
        installHotkey()
        installDebugTrigger()
        refreshSourceMenu()
    }

    // MARK: Menu

    private var sourceMenu = NSMenu()

    private func setupMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "🎬"
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Clip last \(config.bufferSeconds)s (⌃⌥C)",
                                action: #selector(clip), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Trim & share last clip…",
                                action: #selector(trimLast), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "My clips…", action: #selector(showLibrary), keyEquivalent: ""))
        menu.addItem(.separator())
        let srcItem = NSMenuItem(title: "Capture source", action: nil, keyEquivalent: "")
        srcItem.submenu = sourceMenu
        menu.addItem(srcItem)
        menu.addItem(NSMenuItem(title: "Refresh sources", action: #selector(refreshSources), keyEquivalent: ""))
        menu.addItem(.separator())
        let up = NSMenuItem(title: "Upload + copy link on clip", action: #selector(toggleUpload), keyEquivalent: "")
        up.state = config.uploadOnClip ? .on : .off
        uploadItem = up
        menu.addItem(up)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private var uploadItem: NSMenuItem?
    @objc private func toggleUpload() {
        config.uploadOnClip.toggle()
        uploadItem?.state = config.uploadOnClip ? .on : .off
    }

    @objc private func refreshSources() { refreshSourceMenu() }

    private func refreshSourceMenu() {
        Task { @MainActor in
            guard let (displays, windows) = try? await CaptureEngine.sources() else { return }
            sourceMenu.removeAllItems()
            for d in displays {
                let it = NSMenuItem(title: "Display \(d.displayID) (\(d.width)×\(d.height))",
                                    action: #selector(pickDisplay(_:)), keyEquivalent: "")
                it.representedObject = d
                sourceMenu.addItem(it)
            }
            if !windows.isEmpty { sourceMenu.addItem(.separator()) }
            for w in windows.prefix(25) {
                let app = w.owningApplication?.applicationName ?? "?"
                let it = NSMenuItem(title: "\(app) — \(w.title ?? "")",
                                    action: #selector(pickWindow(_:)), keyEquivalent: "")
                it.representedObject = w
                sourceMenu.addItem(it)
            }
        }
    }

    @objc private func pickDisplay(_ sender: NSMenuItem) {
        guard let d = sender.representedObject as? SCDisplay else { return }
        startCapture(source: .display(d))
    }

    @objc private func pickWindow(_ sender: NSMenuItem) {
        guard let w = sender.representedObject as? SCWindow else { return }
        startCapture(source: .window(w))
    }

    // MARK: Capture

    private func startCapture(source: CaptureSource?) {
        currentSource = source
        let capture = self.capture!
        Task { @MainActor in
            do { try await capture.start(source: source) }
            catch { self.log("capture start failed: \(error.localizedDescription)") }
        }
    }

    @objc private func clip() {
        let buffer = self.buffer!
        let dir = config.saveDir
        let shouldUpload = config.uploadOnClip
        let uploader = self.uploader!
        Task.detached {
            guard let url = buffer.flush(to: dir) else {
                await self.log("flush failed (buffer empty or no keyframe yet)")
                return
            }
            await MainActor.run { self.lastClipURL = url }
            await self.notify("Clip saved", url.lastPathComponent)
            guard shouldUpload else { return }
            do {
                let link = try await uploader.upload(url)
                await self.copyAndNotify(link)
            } catch {
                await self.log("upload failed: \(error.localizedDescription)")
                await self.notify("Upload failed", error.localizedDescription)
            }
        }
    }

    @objc private func showLibrary() {
        libraryController.show(client: clipsClient)
    }

    @objc private func trimLast() {
        guard let url = lastClipURL, FileManager.default.fileExists(atPath: url.path) else {
            notify("No clip yet", "Make a clip first (⌃⌥C)")
            return
        }
        trimController.show(url: url) { [weak self] start, end in
            self?.trimAndShare(url, start: start, end: end)
        }
    }

    private func trimAndShare(_ url: URL, start: Double, end: Double) {
        let uploader = self.uploader!
        Task.detached {
            do {
                let trimmed = try await Trimmer.trim(url, start: start, end: end)
                await self.notify("Trimmed", "Uploading \(trimmed.lastPathComponent)…")
                let link = try await uploader.upload(trimmed)
                await self.copyAndNotify(link)
            } catch {
                await self.log("trim/share failed: \(error.localizedDescription)")
                await self.notify("Trim failed", error.localizedDescription)
            }
        }
    }

    private func copyAndNotify(_ link: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(link, forType: .string)
        log("share link copied: \(link)")
        notify("Link copied to clipboard", link)
    }

    private func notify(_ title: String, _ body: String) {
        log("saved \(body)")
        let n = NSUserNotification()
        n.title = title
        n.informativeText = body
        NSUserNotificationCenter.default.deliver(n)
    }

    @objc private func quit() { NSApp.terminate(nil) }

    // MARK: Hotkey + debug trigger

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

    // SIGUSR1 -> clip. Lets dev/CI trigger a flush without UI: `kill -USR1 <pid>`.
    private func installDebugTrigger() {
        signal(SIGUSR1, SIG_IGN)
        let src = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .main)
        src.setEventHandler { [weak self] in self?.clip() }
        src.resume()
        debugSignalSource = src
    }
    private var debugSignalSource: DispatchSourceSignal?

    private func log(_ s: String) {
        FileHandle.standardError.write("[tail] \(s)\n".data(using: .utf8)!)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // menu-bar only, no dock icon
app.run()
