import CoreGraphics
import Foundation

/// Display brightness through DisplayServices, the private framework behind the brightness keys.
/// It reaches the built-in panel and Apple displays; on anything else the curtain is simply black.
@MainActor
final class DisplayBrightness {
    private typealias Get = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias Set = @convention(c) (CGDirectDisplayID, Float) -> Int32
    private typealias Can = @convention(c) (CGDirectDisplayID) -> Bool

    private let get: Get?
    private let set: Set?
    private let can: Can?

    init() {
        let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW)
        get = handle.flatMap { dlsym($0, "DisplayServicesGetBrightness") }.map { unsafeBitCast($0, to: Get.self) }
        set = handle.flatMap { dlsym($0, "DisplayServicesSetBrightness") }.map { unsafeBitCast($0, to: Set.self) }
        can = handle.flatMap { dlsym($0, "DisplayServicesCanChangeBrightness") }.map { unsafeBitCast($0, to: Can.self) }
    }

    /// The displays whose brightness can be read and changed, with their level now.
    func levels() -> [(id: CGDirectDisplayID, brightness: Float)] {
        guard let get, let can else { return [] }
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &ids, &count) == .success else { return [] }
        return ids.prefix(Int(count)).compactMap { id in
            guard can(id) else { return nil }
            var value: Float = 0
            return get(id, &value) == 0 ? (id, value) : nil
        }
    }

    var isAvailable: Bool { !levels().isEmpty }

    func setBrightness(_ value: Float, for id: CGDirectDisplayID) { _ = set?(id, value) }
}
