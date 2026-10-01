import Foundation

/// The curtain's life cycle. The app asks the machine what to do; the machine never touches AppKit.
public enum CurtainPhase: Equatable, Sendable {
    case open        // normal use
    case closing     // fading to black
    case closed      // black screen, keyboard light off, waiting for Esc
    case opening     // levels restored, fading back in
}

public enum CurtainEvent: Equatable, Sendable {
    case closeRequested    // menu item or the shortcut while open
    case wakeRequested     // Esc, or the shortcut while closed
    case fadeFinished
}

/// What the app should do after an event.
public enum CurtainAction: Equatable, Sendable {
    case startClosing      // save levels, cover the screens, fade to black
    case finishClosing     // turn the lights off, take Esc
    case startOpening      // give Esc back, restore the lights, fade in
    case finishOpening     // remove the covers
    case none
}

public struct CurtainMachine: Equatable, Sendable {
    public private(set) var phase: CurtainPhase = .open

    public init() {}

    public mutating func handle(_ event: CurtainEvent) -> CurtainAction {
        switch (phase, event) {
        case (.open, .closeRequested):
            phase = .closing; return .startClosing
        case (.closing, .fadeFinished):
            phase = .closed; return .finishClosing
        // Waking in the middle of the fade turns straight round: nothing is dimmed yet.
        case (.closing, .wakeRequested), (.closed, .wakeRequested):
            phase = .opening; return .startOpening
        case (.opening, .fadeFinished):
            phase = .open; return .finishOpening
        default:
            return .none
        }
    }

    /// The shortcut toggles: it closes an open curtain and opens a closed one.
    public mutating func toggle() -> CurtainAction {
        handle(phase == .open ? .closeRequested : .wakeRequested)
    }

    public var isCovering: Bool { phase != .open }
}
