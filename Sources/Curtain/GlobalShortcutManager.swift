import Carbon
import CurtainCore

/// Carbon hot keys: they need no Accessibility permission and fire whichever app has focus.
/// One is registered for good (the shortcut); Esc is registered only while the curtain is closed,
/// so it wakes the Mac even if another window somehow takes the keyboard, and is left alone otherwise.
@MainActor
final class GlobalShortcutManager {
    enum Key: UInt32 { case toggle = 1, escape = 2 }

    private static let signature: OSType = 0x4354_524E  // "CTRN"
    private var handler: EventHandlerRef?
    private var registered: [Key: EventHotKeyRef] = [:]
    private var down: Set<Key> = []
    var onPress: ((Key) -> Void)?

    func install() throws {
        guard handler == nil else { return }
        var events = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, data in
            guard let data, let event else { return OSStatus(eventNotHandledErr) }
            var identifier = EventHotKeyID()
            let result = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier)
            guard result == noErr, identifier.signature == GlobalShortcutManager.signature,
                  let key = Key(rawValue: identifier.id) else { return OSStatus(eventNotHandledErr) }
            // Carbon delivers this application event on the main thread.
            MainActor.assumeIsolated {
                let manager = Unmanaged<GlobalShortcutManager>.fromOpaque(data).takeUnretainedValue()
                if GetEventKind(event) == UInt32(kEventHotKeyReleased) {
                    manager.down.remove(key)
                } else if !manager.down.contains(key) {
                    manager.down.insert(key)
                    manager.onPress?(key)
                }
            }
            return noErr
        }, events.count, &events, pointer, &handler)
        guard status == noErr else { throw ShortcutError.install(status) }
    }

    func register(_ shortcut: Shortcut) throws {
        var modifiers: UInt32 = 0
        if shortcut.control { modifiers |= UInt32(controlKey) }
        if shortcut.option { modifiers |= UInt32(optionKey) }
        if shortcut.command { modifiers |= UInt32(cmdKey) }
        if shortcut.shift { modifiers |= UInt32(shiftKey) }
        try register(.toggle, keyCode: shortcut.keyCode, modifiers: modifiers)
    }

    func registerEscape() { try? register(.escape, keyCode: UInt32(kVK_Escape), modifiers: 0) }
    func unregisterEscape() { unregister(.escape) }

    private func register(_ key: Key, keyCode: UInt32, modifiers: UInt32) throws {
        guard registered[key] == nil else { return }
        var ref: EventHotKeyRef?
        let result = RegisterEventHotKey(keyCode, modifiers, EventHotKeyID(signature: Self.signature, id: key.rawValue),
                                         GetApplicationEventTarget(), 0, &ref)
        guard result == noErr, let ref else { throw ShortcutError.taken(result) }
        registered[key] = ref
    }

    private func unregister(_ key: Key) {
        if let ref = registered.removeValue(forKey: key) { UnregisterEventHotKey(ref) }
        down.remove(key)
    }
}

enum ShortcutError: Error {
    case install(OSStatus)
    case taken(OSStatus)
}
