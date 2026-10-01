import Foundation

/// The keyboard backlight, through CoreBrightness's KeyboardBrightnessClient: the same private
/// interface Control Centre's keyboard brightness slider uses. macOS has no public API for it,
/// so every call is looked up at run time and a missing piece simply turns the feature off.
@MainActor
final class KeyboardBacklight {
    struct Level { var id: UInt64; var brightness: Float; var autoBrightness: Bool }

    private typealias GetFloat = @convention(c) (AnyObject, Selector, UInt64) -> Float
    private typealias GetBool = @convention(c) (AnyObject, Selector, UInt64) -> Bool
    private typealias SetFloat = @convention(c) (AnyObject, Selector, Float, UInt64) -> Bool
    private typealias SetBool = @convention(c) (AnyObject, Selector, Bool, UInt64) -> Bool

    private let client: NSObject?
    private let getBrightness = NSSelectorFromString("brightnessForKeyboard:")
    private let getAuto = NSSelectorFromString("isAutoBrightnessEnabledForKeyboard:")
    private let setBrightness = NSSelectorFromString("setBrightness:forKeyboard:")
    private let setAuto = NSSelectorFromString("enableAutoBrightness:forKeyboard:")
    private let copyIDs = NSSelectorFromString("copyKeyboardBacklightIDs")

    init() {
        _ = dlopen("/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness", RTLD_NOW)
        let type = NSClassFromString("KeyboardBrightnessClient") as? NSObject.Type
        let candidate = type?.init()
        let selectors = [getBrightness, getAuto, setBrightness, setAuto, copyIDs]
        client = candidate.flatMap { c in selectors.allSatisfy { c.responds(to: $0) } ? c : nil }
    }

    /// The backlit keyboards attached now; empty on a Mac without one (or if the interface changes).
    var keyboardIDs: [UInt64] {
        guard let client, let ids = client.perform(copyIDs)?.takeRetainedValue() as? [NSNumber] else { return [] }
        return ids.map(\.uint64Value)
    }

    var isAvailable: Bool { !keyboardIDs.isEmpty }

    func levels() -> [Level] {
        guard let client else { return [] }
        let brightness = unsafeBitCast(client.method(for: getBrightness), to: GetFloat.self)
        let auto = unsafeBitCast(client.method(for: getAuto), to: GetBool.self)
        return keyboardIDs.map { Level(id: $0, brightness: brightness(client, getBrightness, $0), autoBrightness: auto(client, getAuto, $0)) }
    }

    /// Off: ambient adjustment is paused first, or the light sensor would turn it straight back on.
    func turnOff() {
        for id in keyboardIDs { apply(Level(id: id, brightness: 0, autoBrightness: false)) }
    }

    func apply(_ level: Level) {
        guard let client else { return }
        let set = unsafeBitCast(client.method(for: setBrightness), to: SetFloat.self)
        let auto = unsafeBitCast(client.method(for: setAuto), to: SetBool.self)
        if level.autoBrightness {
            _ = set(client, setBrightness, level.brightness, level.id)
            _ = auto(client, setAuto, true, level.id)
        } else {
            _ = auto(client, setAuto, false, level.id)
            _ = set(client, setBrightness, level.brightness, level.id)
        }
    }
}
