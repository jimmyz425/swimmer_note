import Foundation

public protocol TrainingNoteRepository: Sendable {
    func note(for date: String) async -> TrainingNote?
    func listNotes() async -> [TrainingNote]
    func save(_ note: TrainingNote) async throws
    func delete(date: String) async throws
}

public actor InMemoryTrainingNoteRepository: TrainingNoteRepository {
    private var notesByDate: [String: TrainingNote]

    public init(notes: [TrainingNote] = []) {
        self.notesByDate = Dictionary(uniqueKeysWithValues: notes.map { ($0.date, $0) })
    }

    public func note(for date: String) async -> TrainingNote? {
        notesByDate[date]
    }

    public func listNotes() async -> [TrainingNote] {
        notesByDate.values.sorted { $0.date > $1.date }
    }

    public func save(_ note: TrainingNote) async throws {
        notesByDate[note.date] = note
    }

    public func delete(date: String) async throws {
        notesByDate[date] = nil
    }
}

public protocol FileAccessorProviding: Sendable {
    func read(from url: URL) throws -> Data
    func write(_ data: Data, to url: URL) throws
    func remove(at url: URL) throws
    func contentsOfDirectory(at url: URL) throws -> [URL]
    func ensureDirectory(at url: URL) throws
}

public struct DefaultFileAccessor: FileAccessorProviding {
    public init() {}

    public func read(from url: URL) throws -> Data {
        try Data(contentsOf: url)
    }

    public func write(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        #if os(iOS)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUnlessOpen], ofItemAtPath: url.path)
        #endif
    }

    public func remove(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    public func contentsOfDirectory(at url: URL) throws -> [URL] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
    }

    public func ensureDirectory(at url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}

public actor JSONTrainingNoteRepository: TrainingNoteRepository {
    private let notesDirectory: URL
    private let fileAccessor: any FileAccessorProviding
    private let decoder = SwimNoteJSONDecoder()
    private let encoder = SwimNoteJSONEncoder()

    public init(notesDirectory: URL, fileAccessor: any FileAccessorProviding = DefaultFileAccessor()) {
        self.notesDirectory = notesDirectory
        self.fileAccessor = fileAccessor
    }

    public func note(for date: String) async -> TrainingNote? {
        guard Self.isSafeNoteDate(date) else { return nil }
        let url = notesDirectory.appendingPathComponent("\(date).json")
        guard let data = try? fileAccessor.read(from: url) else { return nil }
        return try? decoder.decode(TrainingNote.self, from: data)
    }

    public func listNotes() async -> [TrainingNote] {
        let urls = (try? fileAccessor.contentsOfDirectory(at: notesDirectory)) ?? []
        return urls
            .filter { $0.pathExtension == "json" }
            .compactMap { url in
                guard let data = try? fileAccessor.read(from: url) else { return nil }
                return try? decoder.decode(TrainingNote.self, from: data)
            }
            .sorted { $0.date > $1.date }
    }

    public func save(_ note: TrainingNote) async throws {
        guard Self.isSafeNoteDate(note.date) else {
            throw SwimNotePersistenceError.invalidDate(note.date)
        }
        try fileAccessor.ensureDirectory(at: notesDirectory)
        let url = notesDirectory.appendingPathComponent("\(note.date).json")
        try fileAccessor.write(encoder.encode(note), to: url)
    }

    public func delete(date: String) async throws {
        guard Self.isSafeNoteDate(date) else {
            throw SwimNotePersistenceError.invalidDate(date)
        }
        let url = notesDirectory.appendingPathComponent("\(date).json")
        try fileAccessor.remove(at: url)
    }

    private static func isSafeNoteDate(_ date: String) -> Bool {
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

public actor InMemoryTechniqueTreeRepository: TechniqueTreeRepository {
    private var treesByStroke: [StrokeID: TechniqueTree]

    public init(trees: [TechniqueTree]) {
        self.treesByStroke = Dictionary(uniqueKeysWithValues: trees.map { ($0.strokeId, $0) })
    }

    public func tree(for strokeId: StrokeID) async throws -> TechniqueTree {
        guard let tree = treesByStroke[strokeId] else {
            throw SwimNotePersistenceError.missingTree(strokeId.rawValue)
        }
        return tree
    }

    public func save(_ tree: TechniqueTree) async throws {
        treesByStroke[tree.strokeId] = tree
    }
}

public enum SwimNotePersistenceError: Error, Equatable, CustomStringConvertible {
    case missingTree(String)
    case cloudKitStoreUnavailable
    case invalidDate(String)

    public var description: String {
        switch self {
        case .missingTree(let strokeId):
            return "No technique tree found for \(strokeId)"
        case .cloudKitStoreUnavailable:
            return "CloudKit-backed Core Data store is unavailable in this environment"
        case .invalidDate(let date):
            return "Invalid note date: \(date)"
        }
    }
}
