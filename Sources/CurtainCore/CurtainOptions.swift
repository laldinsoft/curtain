import Foundation

/// The menu's switches, kept in UserDefaults. Everything is on by default.
public struct CurtainOptions: Equatable, Sendable {
    /// Turn the keyboard backlight off while closed.
    public var keyboardLightOff: Bool
    /// Take the built-in display's brightness to zero while closed (the screen is black either way).
    public var dimDisplay: Bool
    /// Hold the display awake, so macOS does not sleep or lock behind the curtain and only Esc wakes it.
    public var keepAwake: Bool

    public init(keyboardLightOff: Bool = true, dimDisplay: Bool = true, keepAwake: Bool = true) {
        self.keyboardLightOff = keyboardLightOff; self.dimDisplay = dimDisplay; self.keepAwake = keepAwake
    }

    public enum Key: String, CaseIterable, Sendable {
        case keyboardLightOff, dimDisplay, keepAwake
    }

    /// Reads the options from a defaults domain; a key that was never written keeps its default.
    public init(defaults: UserDefaults) {
        let d = CurtainOptions()
        func read(_ key: Key, _ fallback: Bool) -> Bool { defaults.object(forKey: key.rawValue) as? Bool ?? fallback }
        self.init(keyboardLightOff: read(.keyboardLightOff, d.keyboardLightOff),
                  dimDisplay: read(.dimDisplay, d.dimDisplay),
                  keepAwake: read(.keepAwake, d.keepAwake))
    }

    public func save(to defaults: UserDefaults) {
        defaults.set(keyboardLightOff, forKey: Key.keyboardLightOff.rawValue)
        defaults.set(dimDisplay, forKey: Key.dimDisplay.rawValue)
        defaults.set(keepAwake, forKey: Key.keepAwake.rawValue)
    }

    public subscript(key: Key) -> Bool {
        get {
            switch key {
            case .keyboardLightOff: keyboardLightOff
            case .dimDisplay: dimDisplay
            case .keepAwake: keepAwake
            }
        }
        set {
            switch key {
            case .keyboardLightOff: keyboardLightOff = newValue
            case .dimDisplay: dimDisplay = newValue
            case .keepAwake: keepAwake = newValue
            }
        }
    }
}
