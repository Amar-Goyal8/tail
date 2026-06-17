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
    private let onboardingController = OnboardingWindowController()
    private var clipsClient: ClipsClient!
    private var micCapture: MicCapture?
    private let model = AppModel()
    private let mainWindow = MainWindowController()

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "tail" { AuthManager.shared.handle(url: url) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Theme.registerFonts()
        Task { await AuthManager.shared.bootstrap() }
        setupMenu()
        uploader = Uploader(baseURL: config.backendURL)
        clipsClient = ClipsClient(baseURL: config.backendURL)
        buildPipeline()
        startCapture(source: nil)
        installHotkey()
        installDebugTrigger()
        refreshSourceMenu()
        refreshPlan()
        buildQualityMenu()
        setupModel()
        setupGameDetection()
        if OnboardingWindowController.hasOnboarded {
            mainWindow.show(model: model)
        } else {
            onboardingController.showIfNeeded(openScreenRecording: openScreenRecordingSettings)
        }
    }

    // Track the foreground app as the "game" (last non-Tail app shown in top bar).
    private var currentGamePID: pid_t?

    private func setupGameDetection() {
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.updateGame(app)
        }
        nc.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let self, let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            if app.processIdentifier == self.currentGamePID { self.clearGame() }
        }
        for app in NSWorkspace.shared.runningApplications where Self.isGame(app) { updateGame(app); break }
    }

    private func updateGame(_ app: NSRunningApplication) {
        guard Self.isGame(app), let name = app.localizedName else { return }
        currentGamePID = app.processIdentifier
        model.gameName = name
        model.gameIcon = app.icon
        model.gameActive = true
    }

    private func clearGame() {
        currentGamePID = nil
        model.gameName = "Waiting for game…"
        model.gameIcon = nil
        model.gameActive = false
    }

    // Heuristic: a game if its bundle category is games, or a known title — but
    // not a store/launcher (those self-categorize as games).
    private static let knownGames = ["roblox", "minecraft", "valorant", "league of legends",
                                     "counter-strike", "fortnite", "overwatch", "apex", "dota"]
    private static let launchers = ["epic games launcher", "steam", "battle.net", "ea app",
                                    "ea desktop", "origin", "gog galaxy", "riot client",
                                    "ubisoft connect", "rockstar games launcher", "playstation"]
    private static func isGame(_ app: NSRunningApplication) -> Bool {
        guard app.activationPolicy == .regular else { return false }
        let id = (app.bundleIdentifier ?? "").lowercased()
        let name = (app.localizedName ?? "").lowercased()
        if id.hasPrefix("com.apple.") || id == "com.tail.clipper" { return false }
        if launchers.contains(where: { name.contains($0) }) { return false }
        if let url = app.bundleURL, let bundle = Bundle(url: url),
           let cat = bundle.object(forInfoDictionaryKey: "LSApplicationCategoryType") as? String,
           cat.lowercased().contains("games") { return true }
        return knownGames.contains { name.contains($0) || id.contains($0) }
    }

    private func setupModel() {
        model.clipsClient = clipsClient
        model.library = LocalLibrary(dir: config.saveDir)
        model.uploader = uploader
        model.bufferSeconds = config.bufferSeconds
        model.systemAudio = config.systemAudioEnabled
        model.micAudio = config.micEnabled
        model.hotkeyLabel = UserDefaults.standard.string(forKey: "tail.hkLabel") ?? "⌃⌥C"
        model.onSetBuffer = { [weak self] secs in
            guard let self else { return }
            self.config.bufferSeconds = secs; self.model.bufferSeconds = secs
            Task { @MainActor in
                try? await self.capture.stop(); self.buildPipeline(); self.startCapture(source: self.currentSource)
            }
        }
        model.onSetSystemAudio = { [weak self] on in
            guard let self else { return }
            self.config.systemAudioEnabled = on; self.model.systemAudio = on
            Task { @MainActor in
                try? await self.capture.stop(); self.buildPipeline(); self.startCapture(source: self.currentSource)
            }
        }
        model.onSetHotkey = { [weak self] code, mods, label in self?.setHotkey(code, mods, label) }
        model.onOpenSettings = { [weak self] in self?.showSettings() }
        model.selectedInput = config.micDeviceUID
        model.onSetInput = { [weak self] uid in
            guard let self else { return }
            self.config.micDeviceUID = uid; self.model.selectedInput = uid
            if self.config.micEnabled { self.micCapture?.stop(); self.startMic() } // restart with new device
        }
        model.onSetOutput = { [weak self] uid in
            AudioDevices.setDefaultOutput(uid: uid); self?.model.selectedOutput = uid
        }
        model.refreshDevices()
        model.onToggleMic = { [weak self] on in
            guard let self else { return }
            self.config.micEnabled = on; self.model.micAudio = on; self.micItem?.state = on ? .on : .off
            if on { self.startMic() } else { self.micCapture?.stop(); self.micCapture = nil }
        }
        model.uploadOnClip = config.uploadOnClip
        model.micEnabled = config.micEnabled
        model.presetName = currentPresetName
        model.plan = plan
        model.onClip = { [weak self] in self?.clip() }
        model.onTrimLast = { [weak self] in self?.trimLast() }
        model.onPickPreset = { [weak self] name in
            guard let self, let p = Config.presets.first(where: { $0.name == name }) else { return }
            if p.pro && self.plan != "pro" { self.upgrade(); return }
            self.switchPreset(p)
        }
        model.onToggleUpload = { [weak self] on in
            self?.config.uploadOnClip = on; self?.uploadItem?.state = on ? .on : .off
        }
        model.onUpgrade = { [weak self] in self?.upgrade() }
        model.onOpenClipsFolder = { [weak self] in
            guard let self else { return }
            try? FileManager.default.createDirectory(at: self.config.saveDir, withIntermediateDirectories: true)
            NSWorkspace.shared.open(self.config.saveDir)
        }
    }

    private func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    // (Re)build encoder + buffer + capture for the current config (resolution/fps).
    private func buildPipeline() {
        buffer = ReplayBuffer(seconds: config.bufferSeconds, config: config)
        encoder = Encoder(config: config) { [weak self] sample in
            self?.buffer.append(sample)
        }
        capture = CaptureEngine(config: config, encoder: encoder, buffer: buffer)
        if config.micEnabled { micCapture?.stop(); startMic() } // re-point mic at new buffer
    }

    // MARK: Menu

    private var sourceMenu = NSMenu()

    private func setupMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "🎬"
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open Tail", action: #selector(openMainWindow), keyEquivalent: "o"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Clip last \(config.bufferSeconds)s (⌃⌥C)",
                                action: #selector(clip), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Trim & share last clip…",
                                action: #selector(trimLast), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "My clips…", action: #selector(showLibrary), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        let srcItem = NSMenuItem(title: "Capture source", action: nil, keyEquivalent: "")
        srcItem.submenu = sourceMenu
        menu.addItem(srcItem)
        let qItem = NSMenuItem(title: "Quality", action: nil, keyEquivalent: "")
        qItem.submenu = qualityMenu
        menu.addItem(qItem)
        upgradeItem = NSMenuItem(title: "Upgrade to Pro (4K)…", action: #selector(upgrade), keyEquivalent: "")
        menu.addItem(upgradeItem!)
        menu.addItem(NSMenuItem(title: "Refresh sources", action: #selector(refreshSources), keyEquivalent: ""))
        menu.addItem(.separator())
        let micItem = NSMenuItem(title: "Capture microphone", action: #selector(toggleMic), keyEquivalent: "")
        micItem.state = config.micEnabled ? .on : .off
        self.micItem = micItem
        menu.addItem(micItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private var uploadItem: NSMenuItem?
    @objc private func toggleUpload() {
        config.uploadOnClip.toggle()
        uploadItem?.state = config.uploadOnClip ? .on : .off
    }

    private var micItem: NSMenuItem?
    @objc private func toggleMic() {
        config.micEnabled.toggle()
        micItem?.state = config.micEnabled ? .on : .off
        if config.micEnabled { startMic() } else { micCapture?.stop(); micCapture = nil }
    }

    private func startMic() {
        let buffer = self.buffer!
        let mic = MicCapture(deviceUID: config.micDeviceUID) { [weak buffer] sample in buffer?.appendMic(sample) }
        mic.start()
        micCapture = mic
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
        switch source {
        case .window(let w): model.sourceLabel = w.title ?? "Window"
        case .display: model.sourceLabel = "Display"
        case .none: model.sourceLabel = "Main display"
        }
        let capture = self.capture!
        Task { @MainActor in
            do { try await capture.start(source: source) }
            catch { self.log("capture start failed: \(error.localizedDescription)") }
        }
    }

    @objc private func clip() {
        let buffer = self.buffer!
        let dir = config.saveDir
        Task.detached {
            guard let url = buffer.flush(to: dir) else {
                await self.log("flush failed (buffer empty or no keyframe yet)")
                return
            }
            let game = await MainActor.run { self.model.gameActive ? self.model.gameName : self.model.sourceLabel }
            await MainActor.run {
                self.lastClipURL = url
                self.model.library?.add(url, game: game)   // show in library; link created on demand
                self.model.clipsRefreshToken += 1
            }
            await self.notify("Clip saved", url.lastPathComponent)
        }
    }

    // MARK: Quality presets + plan

    private let qualityMenu = NSMenu()
    private var upgradeItem: NSMenuItem?
    private var plan = "free"
    private var currentPresetName = Config.presets.first!.name

    private func refreshPlan() {
        Task { @MainActor in
            if let p = try? await clipsClient.plan() {
                plan = p
                model.plan = p
                upgradeItem?.isHidden = (p == "pro")
                buildQualityMenu()
            }
        }
    }

    private func buildQualityMenu() {
        qualityMenu.removeAllItems()
        for preset in Config.presets {
            let locked = preset.pro && plan != "pro"
            let title = preset.name + (locked ? " 🔒" : "")
            let it = NSMenuItem(title: title, action: #selector(pickPreset(_:)), keyEquivalent: "")
            it.representedObject = preset.name
            it.state = (preset.name == currentPresetName) ? .on : .off
            qualityMenu.addItem(it)
        }
    }

    @objc private func pickPreset(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String,
              let preset = Config.presets.first(where: { $0.name == name }) else { return }
        if preset.pro && plan != "pro" { upgrade(); return }
        switchPreset(preset)
    }

    private func switchPreset(_ preset: Config.Preset) {
        currentPresetName = preset.name
        model.presetName = preset.name
        // Preserve non-resolution settings (backend, save dir, upload toggle).
        var newCfg = preset.config
        newCfg.backendURL = config.backendURL
        newCfg.saveDir = config.saveDir
        newCfg.uploadOnClip = config.uploadOnClip
        config = newCfg
        Task { @MainActor in
            try? await capture.stop()
            buildPipeline()
            startCapture(source: currentSource)
            buildQualityMenu()
            notify("Quality set", preset.name)
        }
    }

    @objc private func upgrade() {
        Task { @MainActor in
            if let urlStr = (try? await clipsClient.checkoutURL()) ?? nil, let url = URL(string: urlStr) {
                NSWorkspace.shared.open(url)
            } else {
                notify("Pro coming soon", "Billing isn't set up yet — 4K unlocks once it is.")
            }
        }
    }

    @objc private func openMainWindow() { mainWindow.show(model: model) }

    @objc private func showLibrary() {
        mainWindow.show(model: model) // main window has the Clips library
    }

    @objc private func showSettings() {
        mainWindow.show(model: model)
        model.showSettings = true
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
        Task.detached {
            do {
                let trimmed = try await Trimmer.trim(url, start: start, end: end)
                await MainActor.run {
                    self.model.library?.add(trimmed)
                    self.model.clipsRefreshToken += 1
                }
                await self.notify("Trimmed clip saved", "Create a link from your library to share.")
            } catch {
                await self.log("trim failed: \(error.localizedDescription)")
                await self.notify("Trim failed", error.localizedDescription)
            }
        }
    }

    private func copyAndNotify(_ link: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(link, forType: .string)
        log("share link copied: \(link)")
        model.lastLink = link
        model.clipsRefreshToken += 1
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

    private var hotkeyCode = UInt32(UserDefaults.standard.object(forKey: "tail.hkCode") as? Int ?? 8)
    private var hotkeyMods = UInt32(UserDefaults.standard.object(forKey: "tail.hkMods") as? Int ?? (controlKey | optionKey))

    // Global Carbon hotkey (configurable). No TCC permission needed.
    private func installHotkey() {
        hotKey = HotKey(keyCode: hotkeyCode, modifiers: hotkeyMods) { [weak self] in
            Task { @MainActor in self?.clip() }
        }
        log("hotkey registered")
    }

    private func setHotkey(_ code: UInt32, _ mods: UInt32, _ label: String) {
        hotkeyCode = code; hotkeyMods = mods
        UserDefaults.standard.set(Int(code), forKey: "tail.hkCode")
        UserDefaults.standard.set(Int(mods), forKey: "tail.hkMods")
        UserDefaults.standard.set(label, forKey: "tail.hkLabel")
        model.hotkeyLabel = label
        installHotkey() // old HotKey deinits + unregisters
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
app.setActivationPolicy(.regular) // real app: dock icon + main window (+ menu bar)
app.run()
