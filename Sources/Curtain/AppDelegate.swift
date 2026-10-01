import AppKit
import CurtainCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let shortcut = Shortcut.standard
    private let shortcuts = GlobalShortcutManager()
    private lazy var curtain = CurtainController(shortcuts: shortcuts)
    private var menu: MenuBarController?
    private var options = CurtainOptions(defaults: .standard)
    private var signalSources: [DispatchSourceSignal] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        let args = CommandLine.arguments
        if args.contains("--probe") { probe(); return }

        curtain.recoverIfNeeded()
        // A logout, `kill` or Ctrl-C restores the lights before exiting; a crash is undone at the next launch.
        for sig in [SIGTERM, SIGINT, SIGHUP] {
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler { [weak self] in
                MainActor.assumeIsolated { self?.curtain.openImmediately() }
                exit(0)
            }
            source.resume()
            signalSources.append(source)
        }
        curtain.options = { [unowned self] in options }

        let menu = MenuBarController(shortcut: shortcut)
        menu.onClose = { [unowned self] in
            // Let the menu finish closing before the screen goes.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { self.curtain.close() }
        }
        menu.onToggleOption = { [unowned self] key in
            options[key].toggle()
            options.save(to: .standard)
            refreshMenu()
        }
        menu.onToggleLogin = { [unowned self] in toggleLogin() }
        menu.onAbout = {
            NSApp.activate()
            NSApp.orderFrontStandardAboutPanel(options: [
                .credits: NSAttributedString(string: "Press Control–Option–C to close the curtain. Press Esc to open it.\nhttps://github.com/laldinsoft/curtain")
            ])
        }
        menu.onQuit = { NSApp.terminate(nil) }
        menu.onOpenMenu = { [unowned self] in refreshMenu() }
        self.menu = menu
        refreshMenu()

        shortcuts.onPress = { [unowned self] key in
            switch key {
            case .toggle: curtain.toggle()
            case .escape: curtain.wake()
            }
        }
        do {
            try shortcuts.install()
            try shortcuts.register(shortcut)
        } catch {
            menu.shortcutUnavailable(shortcut)
        }

        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.curtain.didWake() }
            }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.curtain.screensChanged() }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.curtain.appResignedActive() }
        }

        // Debug: close at launch and open again after N seconds, for testing without a keyboard.
        if let i = args.firstIndex(of: "--close-for"), i + 1 < args.count, let seconds = Double(args[i + 1]) {
            curtain.close()
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in self?.curtain.wake() }
        }
    }

    func applicationWillTerminate(_ notification: Notification) { curtain.openImmediately() }

    private func refreshMenu() {
        menu?.update(options: options, keyboardAvailable: curtain.keyboardLightAvailable,
                     displayAvailable: curtain.displayDimmingAvailable)
        menu?.updateLoginItem(enabled: LoginItemManager.isEnabled, requiresApproval: LoginItemManager.needsApproval)
    }

    private func toggleLogin() {
        if LoginItemManager.needsApproval { LoginItemManager.openSettings(); return }
        do { try LoginItemManager.setEnabled(!LoginItemManager.isEnabled) } catch { LoginItemManager.openSettings() }
        refreshMenu()
    }

    /// `--probe`: report which controls this Mac offers, change nothing, and quit.
    private func probe() {
        let keyboard = KeyboardBacklight()
        let display = DisplayBrightness()
        print("keyboard backlight: \(keyboard.isAvailable ? "\(keyboard.levels().count) keyboard(s)" : "not available")")
        print("display brightness: \(display.isAvailable ? "\(display.levels().count) display(s)" : "not available")")
        print("screens: \(NSScreen.screens.count)")
        NSApp.terminate(nil)
    }
}
