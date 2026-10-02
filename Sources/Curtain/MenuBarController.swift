import AppKit
import CurtainCore

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let close = NSMenuItem(title: "Close Curtain", action: nil, keyEquivalent: "")
    private let shortcutNote = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let keyboard = NSMenuItem(title: "Turn Off Keyboard Light", action: nil, keyEquivalent: "")
    private let dim = NSMenuItem(title: "Dim the Display", action: nil, keyEquivalent: "")
    private let awake = NSMenuItem(title: "Keep Mac Awake", action: nil, keyEquivalent: "")
    private let software = NSMenuItem(title: "Let Apps and Agents Type and Click", action: nil, keyEquivalent: "")
    private let login = NSMenuItem(title: "Launch at Login", action: nil, keyEquivalent: "")
    var onClose: (() -> Void)?
    var onToggleOption: ((CurtainOptions.Key) -> Void)?
    var onToggleLogin: (() -> Void)?
    var onSoftwareInput: (() -> Void)?
    var onAbout: (() -> Void)?
    var onQuit: (() -> Void)?
    var onOpenMenu: (() -> Void)?

    init(shortcut: Shortcut) {
        super.init()
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        let title = NSMenuItem(title: "Curtain", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(.separator())
        close.target = self
        close.action = #selector(closeCurtain)
        // The Carbon registration handles the shortcut, including when this menu is closed.
        close.title = "Close Curtain  \(shortcut.symbols)"
        menu.addItem(close)
        shortcutNote.isEnabled = false
        shortcutNote.title = "Press Esc to open it again"
        menu.addItem(shortcutNote)
        menu.addItem(.separator())
        let header = NSMenuItem(title: "While Closed", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        for (entry, key) in [(keyboard, CurtainOptions.Key.keyboardLightOff), (dim, .dimDisplay), (awake, .keepAwake)] {
            entry.target = self
            entry.action = #selector(toggleOption(_:))
            entry.representedObject = key.rawValue
            entry.indentationLevel = 1
            menu.addItem(entry)
        }
        awake.toolTip = "Stops the Mac sleeping or locking behind the curtain, so only Esc brings the screen back."
        software.target = self
        software.action = #selector(softwareInput)
        software.indentationLevel = 1
        menu.addItem(software)
        menu.addItem(.separator())
        login.target = self
        login.action = #selector(toggleLogin)
        menu.addItem(login)
        let about = NSMenuItem(title: "About Curtain", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)
        let quit = NSMenuItem(title: "Quit Curtain", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        item.menu = menu
        item.button?.image = NSImage(systemSymbolName: "curtains.open", accessibilityDescription: "Curtain")
            ?? NSImage(systemSymbolName: "moon", accessibilityDescription: "Curtain")
        item.button?.toolTip = "Curtain · \(shortcut.spoken) to close, Esc to open"
        item.button?.setAccessibilityLabel("Curtain")
    }

    func menuWillOpen(_ menu: NSMenu) { onOpenMenu?() }

    func update(options: CurtainOptions, keyboardAvailable: Bool, displayAvailable: Bool) {
        keyboard.state = options.keyboardLightOff && keyboardAvailable ? .on : .off
        keyboard.isEnabled = keyboardAvailable
        keyboard.toolTip = keyboardAvailable ? nil : "No backlit keyboard found on this Mac."
        dim.state = options.dimDisplay && displayAvailable ? .on : .off
        dim.isEnabled = displayAvailable
        dim.toolTip = displayAvailable ? "Takes the display's brightness to zero as well as covering it in black."
                                       : "This display's brightness can't be changed; the curtain is still black."
        awake.state = options.keepAwake ? .on : .off
    }

    func updateSoftwareInput(allowed: Bool) {
        software.state = allowed ? .on : .off
        software.title = allowed ? "Let Apps and Agents Type and Click" : "Let Apps and Agents Type and Click — Needs Access…"
        software.toolTip = allowed
            ? "Only the physical keyboard, trackpad and mouse are blocked; software and agents keep typing and clicking. Turn off in Privacy & Security ▸ Accessibility."
            : "Give Curtain Accessibility access so software and agents can keep working while closed. Until then, all input is blocked."
    }

    func updateLoginItem(enabled: Bool, requiresApproval: Bool) {
        login.state = enabled ? .on : (requiresApproval ? .mixed : .off)
        login.title = requiresApproval ? "Launch at Login — Approval Needed…" : "Launch at Login"
    }

    func shortcutUnavailable(_ shortcut: Shortcut) {
        close.title = "Close Curtain"
        shortcutNote.title = "\(shortcut.spoken) is taken by another app"
        item.button?.toolTip = "Curtain · Esc to open"
    }

    @objc private func closeCurtain() { onClose?() }
    @objc private func toggleOption(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let key = CurtainOptions.Key(rawValue: raw) else { return }
        onToggleOption?(key)
    }
    @objc private func toggleLogin() { onToggleLogin?() }
    @objc private func softwareInput() { onSoftwareInput?() }
    @objc private func showAbout() { onAbout?() }
    @objc private func quitApp() { onQuit?() }
}
