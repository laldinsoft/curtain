import Foundation

/// The light levels in force before the curtain closed. Written to disk before anything is dimmed and
/// deleted once everything is restored, so a crash or a forced quit is undone at the next launch.
public struct RestoreRecord: Codable, Equatable, Sendable {
    public struct Display: Codable, Equatable, Sendable {
        public var id: UInt32
        public var brightness: Float
        public init(id: UInt32, brightness: Float) { self.id = id; self.brightness = brightness }
    }

    public struct Keyboard: Codable, Equatable, Sendable {
        public var id: UInt64
        public var brightness: Float
        public var autoBrightness: Bool
        public init(id: UInt64, brightness: Float, autoBrightness: Bool) {
            self.id = id; self.brightness = brightness; self.autoBrightness = autoBrightness
        }
    }

    public var savedAt: Date
    public var displays: [Display]
    public var keyboards: [Keyboard]

    public init(savedAt: Date = Date(), displays: [Display] = [], keyboards: [Keyboard] = []) {
        self.savedAt = savedAt; self.displays = displays; self.keyboards = keyboards
    }

    public var isEmpty: Bool { displays.isEmpty && keyboards.isEmpty }
}

/// One small JSON file in Application Support.
public struct RestoreStore: Sendable {
    public let url: URL

    public init(url: URL) { self.url = url }

    /// ~/Library/Application Support/Curtain/restore.json
    public static func standard() -> RestoreStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return RestoreStore(url: base.appendingPathComponent("Curtain/restore.json"))
    }

    public func save(_ record: RestoreRecord) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(record).write(to: url, options: .atomic)
    }

    /// nil when there is nothing to restore. An unreadable file is treated as nothing and removed,
    /// so a damaged record can never block the app.
    public func load() -> RestoreRecord? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let record = try? decoder.decode(RestoreRecord.self, from: data) else { clear(); return nil }
        return record
    }

    public func clear() { try? FileManager.default.removeItem(at: url) }
}
