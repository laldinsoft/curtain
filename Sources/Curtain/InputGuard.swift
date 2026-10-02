import AppKit
import ApplicationServices
import CurtainCore

/// While the curtain is closed, drops every event from the physical keyboard, trackpad and mouse
/// except Esc, and lets through events that software posts (automation, agents, remote control),
/// so work carries on behind the curtain while nobody at the Mac can type or click into it.
///
/// An event tap that can drop events needs Accessibility access. Without it the curtain falls back
/// to swallowing input in its own windows, which stops software input as well.
@MainActor
final class InputGuard {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    /// Called when Esc is pressed on a physical keyboard.
    var onEscape: (() -> Void)?

    static var hasAccess: Bool { AXIsProcessTrusted() }

    /// Shows the system prompt the first time; after that, opens Privacy & Security ▸ Accessibility.
    static func requestAccess() {
        let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        if !AXIsProcessTrustedWithOptions([prompt: true] as CFDictionary),
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// True while the tap is installed, enabled and still allowed to drop events.
    var isWorking: Bool {
        guard let tap else { return false }
        return CGEvent.tapIsEnabled(tap: tap) && Self.hasAccess
    }

    /// Installs the tap. Returns false, changing nothing, when Accessibility access is missing.
    func start() -> Bool {
        if tap != nil { return true }
        guard Self.hasAccess,
              let tap = CGEvent.tapCreate(tap: .cghidEventTap, place: .headInsertEventTap, options: .defaultTap,
                                          eventsOfInterest: ~CGEventMask(0), callback: inputGuardCallback,
                                          userInfo: Unmanaged.passUnretained(self).toOpaque())
        else { return false }
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.source = source
        return true
    }

    func stop() {
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        CFMachPortInvalidate(tap)
        self.tap = nil
        self.source = nil
    }

    fileprivate func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // macOS switches a slow tap off; switch it straight back on.
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        default:
            break
        }
        // Software posts carry the poster's process ID; the keyboard, trackpad and mouse carry none.
        if event.getIntegerValueField(.eventSourceUnixProcessID) != 0 { return Unmanaged.passUnretained(event) }
        if type == .keyDown, WakeKey.wakes(keyCode: UInt16(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode))) {
            // Not from inside the callback: opening removes this tap.
            DispatchQueue.main.async { [weak self] in self?.onEscape?() }
        }
        return nil
    }
}

/// The tap's run loop source is on the main run loop, so this runs on the main thread.
private let inputGuardCallback: CGEventTapCallBack = { _, type, event, info in
    guard let info else { return Unmanaged.passUnretained(event) }
    return MainActor.assumeIsolated {
        Unmanaged<InputGuard>.fromOpaque(info).takeUnretainedValue().handle(type, event)
    }
}
