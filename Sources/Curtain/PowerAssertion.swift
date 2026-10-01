import Foundation
import IOKit.pwr_mgt

/// Keeps the display (and so the Mac) from idling to sleep while the curtain is closed, so macOS
/// never sleeps or locks behind it and only Esc brings the screen back.
final class PowerAssertion {
    private var id: IOPMAssertionID = 0
    private var held = false

    func hold() {
        guard !held else { return }
        held = IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                                           IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                           "Curtain is closed" as CFString, &id) == kIOReturnSuccess
    }

    func release() {
        guard held else { return }
        IOPMAssertionRelease(id)
        held = false
    }

    deinit { release() }
}
