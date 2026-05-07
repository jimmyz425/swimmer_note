@preconcurrency import Foundation

public protocol TrainingNoteRepository: Sendable {
    func note(for userId: String, date: String) async -> TrainingNote?
    func listNotes(for userId: String) async -> [TrainingNote]
    func save(_ note: TrainingNote) async throws
    func delete(userId: String, date: String) async throws
}

public protocol FileAccessorProviding: Sendable {
    nonisolated func read(from url: URL) throws -> Data
    nonisolated func write(_ data: Data, to url: URL) throws
    nonisolated func remove(at url: URL) throws
    nonisolated func contentsOfDirectory(at url: URL) throws -> [URL]
    nonisolated func ensureDirectory(at url: URL) throws
}

public struct DefaultFileAccessor: FileAccessorProviding {
    public nonisolated init() {}

    public nonisolated func read(from url: URL) throws -> Data {
        try Data(contentsOf: url)
    }

    public nonisolated func write(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        #if os(iOS)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUnlessOpen], ofItemAtPath: url.path)
        #endif
    }

    public nonisolated func remove(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    public nonisolated func contentsOfDirectory(at url: URL) throws -> [URL] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
    }

    public nonisolated func ensureDirectory(at url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}

public actor JSONTrainingNoteRepository: TrainingNoteRepository {
    private let notesDirectory: URL
    private let fileAccessor: any FileAccessorProviding

    public init(notesDirectory: URL, fileAccessor: any FileAccessorProviding = DefaultFileAccessor()) {
        self.notesDirectory = notesDirectory
        self.fileAccessor = fileAccessor
    }

    private static func decodeNote(from data: Data) async -> TrainingNote? {
        let decoder = JSONDecoder()
        return try? decoder.decode(TrainingNote.self, from: data)
    }

    private static func encodeNote(_ note: TrainingNote) async -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(note)
    }

    private func userNotesDirectory(userId: String) -> URL {
        notesDirectory.appendingPathComponent(userId, isDirectory: true)
    }

    public func note(for userId: String, date: String) async -> TrainingNote? {
        guard Self.isSafeNoteDate(date), Self.isSafeId(userId) else { return nil }
        let url = userNotesDirectory(userId: userId).appendingPathComponent("\(date).json")
        guard let data = try? fileAccessor.read(from: url) else { return nil }
        return await Self.decodeNote(from: data)
    }

    public func listNotes(for userId: String) async -> [TrainingNote] {
        guard Self.isSafeId(userId) else { return [] }
        try? fileAccessor.ensureDirectory(at: userNotesDirectory(userId: userId))
        let urls = (try? fileAccessor.contentsOfDirectory(at: userNotesDirectory(userId: userId))) ?? []
        var results: [TrainingNote] = []
        for url in urls where url.pathExtension == "json" {
            guard let data = try? fileAccessor.read(from: url) else { continue }
            if let note = await Self.decodeNote(from: data) {
                results.append(note)
            }
        }
        return results.sorted { $0.date > $1.date }
    }

    public func save(_ note: TrainingNote) async throws {
        guard Self.isSafeNoteDate(note.date), Self.isSafeId(note.userId) else {
            throw SwimNotePersistenceError.invalidDate(note.date)
        }
        let userDir = userNotesDirectory(userId: note.userId)
        try fileAccessor.ensureDirectory(at: userDir)
        let url = userDir.appendingPathComponent("\(note.date).json")
        guard let data = await Self.encodeNote(note) else {
            throw SwimNotePersistenceError.encodingFailed
        }
        try fileAccessor.write(data, to: url)
    }

    public func delete(userId: String, date: String) async throws {
        guard Self.isSafeNoteDate(date), Self.isSafeId(userId) else {
            throw SwimNotePersistenceError.invalidDate(date)
        }
        let url = userNotesDirectory(userId: userId).appendingPathComponent("\(date).json")
        try fileAccessor.remove(at: url)
    }

    private nonisolated static func isSafeId(_ id: String) -> Bool {
        !id.isEmpty && id.count <= 64 && !id.contains("/") && !id.contains("\\") && !id.contains("..")
    }

    private nonisolated static func isSafeNoteDate(_ date: String) -> Bool {
        let pattern = #"^\d{4}-\d{2}-\d{2}$"#
        guard date.range(of: pattern, options: .regularExpression) != nil else { return false }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter.date(from: date) != nil
            && !date.contains("/")
            && !date.contains("\\")
            && !date.contains("..")
    }
}

public protocol TechniqueTreeRepository: Sendable {
    func tree(for strokeId: StrokeID) async throws -> TechniqueTree
    func save(_ tree: TechniqueTree) async throws
}

public enum SwimNotePersistenceError: Error, Equatable, CustomStringConvertible {
    case missingTree(String)
    case cloudKitStoreUnavailable
    case invalidDate(String)
    case encodingFailed

    public var description: String {
        switch self {
        case .missingTree(let strokeId):
            return "No technique tree found for \(strokeId)"
        case .cloudKitStoreUnavailable:
            return "CloudKit-backed Core Data store is unavailable in this environment"
        case .invalidDate(let date):
            return "Invalid note date: \(date)"
        case .encodingFailed:
            return "Failed to encode training note"
        }
    }
}
