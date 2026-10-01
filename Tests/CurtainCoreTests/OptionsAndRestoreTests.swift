import XCTest
@testable import CurtainCore

final class OptionsAndRestoreTests: XCTestCase {
    func testOptionsDefaultOnAndRoundTrip() {
        let name = "curtain-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        XCTAssertEqual(CurtainOptions(defaults: defaults), CurtainOptions())
        var o = CurtainOptions()
        o[.keepAwake] = false
        o[.dimDisplay] = false
        o.save(to: defaults)
        let back = CurtainOptions(defaults: defaults)
        XCTAssertTrue(back.keyboardLightOff)
        XCTAssertFalse(back.dimDisplay)
        XCTAssertFalse(back.keepAwake)
    }

    private func tempStore() -> RestoreStore {
        RestoreStore(url: FileManager.default.temporaryDirectory
            .appendingPathComponent("curtain-tests-\(UUID().uuidString)/restore.json"))
    }

    func testRestoreRoundTrip() throws {
        let store = tempStore()
        defer { try? FileManager.default.removeItem(at: store.url.deletingLastPathComponent()) }
        XCTAssertNil(store.load())
        let record = RestoreRecord(savedAt: Date(timeIntervalSince1970: 1_790_000_000),
                                   displays: [.init(id: 1, brightness: 0.334)],
                                   keyboards: [.init(id: 95_158_272, brightness: 0.228, autoBrightness: true)])
        try store.save(record)
        XCTAssertEqual(store.load(), record)
        store.clear()
        XCTAssertNil(store.load())
    }

    func testDamagedRecordIsDropped() throws {
        let store = tempStore()
        defer { try? FileManager.default.removeItem(at: store.url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: store.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: store.url)
        XCTAssertNil(store.load())
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.url.path))
    }

    func testEmptyRecord() {
        XCTAssertTrue(RestoreRecord().isEmpty)
        XCTAssertFalse(RestoreRecord(keyboards: [.init(id: 1, brightness: 0, autoBrightness: false)]).isEmpty)
    }
}
