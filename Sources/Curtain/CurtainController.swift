import AppKit
import CurtainCore

/// Closes and opens the curtain: covers every screen, turns the lights down, and puts everything
/// back exactly as it was when Esc is pressed. The phases come from `CurtainMachine`.
@MainActor
final class CurtainController {
    private var machine = CurtainMachine()
    private var windows: [CurtainWindow] = []
    private var fadeID = 0
    private var reassert: Timer?
    private var cursorHidden = false
    private let keyboard = KeyboardBacklight()
    private let display = DisplayBrightness()
    private let power = PowerAssertion()
    private let store = RestoreStore.standard()
    let shortcuts: GlobalShortcutManager
    var options: () -> CurtainOptions = { CurtainOptions() }
    var onPhaseChange: ((CurtainPhase) -> Void)?

    static let closeFade: TimeInterval = 0.6
    static let openFade: TimeInterval = 0.35

    init(shortcuts: GlobalShortcutManager) { self.shortcuts = shortcuts }

    var phase: CurtainPhase { machine.phase }
    var keyboardLightAvailable: Bool { keyboard.isAvailable }
    var displayDimmingAvailable: Bool { display.isAvailable }

    func close() { perform(machine.handle(.closeRequested)) }
    func wake() { perform(machine.handle(.wakeRequested)) }
    func toggle() { perform(machine.toggle()) }

    /// Puts back levels left behind by a crash or a forced quit while the curtain was closed.
    func recoverIfNeeded() {
        guard let record = store.load() else { return }
        restore(record)
        store.clear()
    }

    /// Called on quit: restore synchronously, no fade.
    func openImmediately() {
        guard machine.isCovering else { return }
        if let record = store.load() { restore(record) }
        store.clear()
        tearDown()
        machine = CurtainMachine()
        onPhaseChange?(.open)
    }

    // MARK: - Phases

    private func perform(_ action: CurtainAction) {
        switch action {
        case .startClosing: startClosing()
        case .finishClosing: lightsOff()
        case .startOpening: startOpening()
        case .finishOpening: tearDown()
        case .none: return
        }
        onPhaseChange?(machine.phase)
    }

    private func startClosing() {
        let opts = options()
        // Record the levels before touching anything, so they survive a crash.
        var record = RestoreRecord()
        if opts.keyboardLightOff {
            record.keyboards = keyboard.levels().map { .init(id: $0.id, brightness: $0.brightness, autoBrightness: $0.autoBrightness) }
        }
        if opts.dimDisplay {
            record.displays = display.levels().map { .init(id: $0.id, brightness: $0.brightness) }
        }
        if !record.isEmpty { try? store.save(record) }

        shortcuts.registerEscape()
        if opts.keepAwake { power.hold() }
        buildWindows(alpha: 0)
        NSApp.activate()
        NSApp.presentationOptions = [.hideDock, .hideMenuBar, .disableProcessSwitching, .disableHideApplication, .disableAppleMenu]
        hideCursor()
        fade(to: 1, duration: Self.closeFade)
    }

    private func lightsOff() {
        applyDarkLevels()
        // The light sensor, the brightness keys or a wake from sleep can bring a light back; keep it down.
        reassert = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
            MainActor.assumeIsolated { [weak self] in self?.applyDarkLevels() }
        }
    }

    private func applyDarkLevels() {
        guard machine.phase == .closed else { return }
        let opts = options()
        if opts.keyboardLightOff { keyboard.turnOff() }
        if opts.dimDisplay { for level in display.levels() where level.brightness > 0 { display.setBrightness(0, for: level.id) } }
    }

    private func startOpening() {
        shortcuts.unregisterEscape()
        reassert?.invalidate(); reassert = nil
        if let record = store.load() { restore(record) }
        store.clear()
        fade(to: 0, duration: Self.openFade)
    }

    private func tearDown() {
        reassert?.invalidate(); reassert = nil
        shortcuts.unregisterEscape()
        for window in windows { window.orderOut(nil) }
        windows = []
        NSApp.presentationOptions = []
        showCursor()
        power.release()
    }

    private func restore(_ record: RestoreRecord) {
        for d in record.displays { display.setBrightness(d.brightness, for: d.id) }
        for k in record.keyboards { keyboard.apply(.init(id: k.id, brightness: k.brightness, autoBrightness: k.autoBrightness)) }
    }

    // MARK: - Covers

    private func buildWindows(alpha: CGFloat) {
        for window in windows { window.orderOut(nil) }
        windows = NSScreen.screens.map { screen in
            let window = CurtainWindow(screen: screen)
            window.alphaValue = alpha
            window.onEscape = { [weak self] in self?.wake() }
            window.orderFrontRegardless()
            return window
        }
        // The window under the pointer (or the first) takes the keyboard, so typing goes nowhere.
        let mouse = NSEvent.mouseLocation
        (windows.first { $0.frame.contains(mouse) } ?? windows.first)?.makeKeyAndOrderFront(nil)
    }

    /// Screens added, removed or rearranged while closed get their own cover.
    func screensChanged() {
        guard machine.isCovering else { return }
        buildWindows(alpha: windows.first?.alphaValue ?? 1)
    }

    /// After a sleep or a display wake the lights may come back on their own.
    func didWake() {
        guard machine.phase == .closed else { return }
        buildWindows(alpha: 1)
        NSApp.activate()
        applyDarkLevels()
    }

    /// If something else takes focus while closed, take it back.
    func appResignedActive() {
        guard machine.isCovering else { return }
        DispatchQueue.main.async {
            guard self.machine.isCovering else { return }
            NSApp.activate()
            (self.windows.first { $0.isKeyWindow } ?? self.windows.first)?.makeKeyAndOrderFront(nil)
        }
    }

    private func fade(to alpha: CGFloat, duration: TimeInterval) {
        fadeID += 1
        let id = fadeID
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            for window in windows { window.animator().alphaValue = alpha }
        }, completionHandler: {
            MainActor.assumeIsolated { [weak self] in
                // A fade interrupted by the opposite one finishes silently.
                guard let self, id == self.fadeID else { return }
                self.perform(self.machine.handle(.fadeFinished))
            }
        })
    }

    private func hideCursor() {
        guard !cursorHidden else { return }
        NSCursor.hide(); cursorHidden = true
    }

    private func showCursor() {
        guard cursorHidden else { return }
        NSCursor.unhide(); cursorHidden = false
    }
}
