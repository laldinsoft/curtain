import XCTest
@testable import CurtainCore

final class CurtainMachineTests: XCTestCase {
    func testFullCycle() {
        var m = CurtainMachine()
        XCTAssertEqual(m.handle(.closeRequested), .startClosing)
        XCTAssertEqual(m.phase, .closing)
        XCTAssertEqual(m.handle(.fadeFinished), .finishClosing)
        XCTAssertEqual(m.phase, .closed)
        XCTAssertTrue(m.isCovering)
        XCTAssertEqual(m.handle(.wakeRequested), .startOpening)
        XCTAssertEqual(m.handle(.fadeFinished), .finishOpening)
        XCTAssertEqual(m.phase, .open)
        XCTAssertFalse(m.isCovering)
    }

    func testWakeDuringTheFadeTurnsRound() {
        var m = CurtainMachine()
        _ = m.handle(.closeRequested)
        XCTAssertEqual(m.handle(.wakeRequested), .startOpening)
        XCTAssertEqual(m.phase, .opening)
        // The closing fade's completion arrives late and must not close it again.
        XCTAssertEqual(m.handle(.fadeFinished), .finishOpening)
        XCTAssertEqual(m.phase, .open)
    }

    func testRepeatedRequestsAreIgnored() {
        var m = CurtainMachine()
        XCTAssertEqual(m.handle(.wakeRequested), .none)
        XCTAssertEqual(m.handle(.fadeFinished), .none)
        _ = m.handle(.closeRequested)
        XCTAssertEqual(m.handle(.closeRequested), .none)
        _ = m.handle(.fadeFinished)
        XCTAssertEqual(m.handle(.closeRequested), .none)
        _ = m.handle(.wakeRequested)
        XCTAssertEqual(m.handle(.wakeRequested), .none)
        XCTAssertEqual(m.handle(.closeRequested), .none)
    }

    func testShortcutToggles() {
        var m = CurtainMachine()
        XCTAssertEqual(m.toggle(), .startClosing)
        _ = m.handle(.fadeFinished)
        XCTAssertEqual(m.toggle(), .startOpening)
        _ = m.handle(.fadeFinished)
        XCTAssertEqual(m.toggle(), .startClosing)
    }

    func testOnlyEscapeWakes() {
        XCTAssertTrue(WakeKey.wakes(keyCode: 53))
        for code: UInt16 in [0, 8, 36, 48, 49, 51, 122, 126] { XCTAssertFalse(WakeKey.wakes(keyCode: code)) }
    }

    func testShortcutText() {
        XCTAssertEqual(Shortcut.standard.symbols, "⌃⌥C")
        XCTAssertEqual(Shortcut.standard.spoken, "Control–Option–C")
        let all = Shortcut(keyCode: 0, control: true, option: true, command: true, shift: true, key: "A")
        XCTAssertEqual(all.symbols, "⌃⌥⇧⌘A")
    }
}
