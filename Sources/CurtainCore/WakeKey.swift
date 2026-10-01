import Foundation

/// Only Esc lifts the curtain. Every other key, click and gesture is swallowed while it is closed.
public enum WakeKey {
    /// kVK_Escape from Carbon's Events.h.
    public static let escapeKeyCode: UInt16 = 53

    public static func wakes(keyCode: UInt16) -> Bool { keyCode == escapeKeyCode }
}

/// The global shortcut that closes (and, as a fallback, opens) the curtain.
public struct Shortcut: Equatable, Sendable {
    public var keyCode: UInt32
    public var control: Bool
    public var option: Bool
    public var command: Bool
    public var shift: Bool
    public var key: String

    /// Control–Option–C, in the same family as DayScribe's Control–Option–N.
    public static let standard = Shortcut(keyCode: 8, control: true, option: true, command: false, shift: false, key: "C")

    public init(keyCode: UInt32, control: Bool, option: Bool, command: Bool, shift: Bool, key: String) {
        self.keyCode = keyCode; self.control = control; self.option = option
        self.command = command; self.shift = shift; self.key = key
    }

    /// Menu glyphs in Apple's order: ⌃⌥⇧⌘.
    public var symbols: String {
        (control ? "⌃" : "") + (option ? "⌥" : "") + (shift ? "⇧" : "") + (command ? "⌘" : "") + key
    }

    /// Spelled out for tooltips and the README: "Control–Option–C".
    public var spoken: String {
        ([control ? "Control" : nil, option ? "Option" : nil, shift ? "Shift" : nil, command ? "Command" : nil]
            .compactMap { $0 } + [key]).joined(separator: "–")
    }
}
