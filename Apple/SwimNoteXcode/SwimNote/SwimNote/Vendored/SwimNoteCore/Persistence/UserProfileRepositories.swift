@preconcurrency import Foundation

public protocol UserProfileRepository: Sendable {
    func listProfiles() async -> [UserProfile]
    func profile(id: String) async -> UserProfile?
    func save(_ profile: UserProfile) async throws
    func delete(id: String) async throws
    func activeProfileId() async -> String?
    func setActiveProfile(id: String) async throws
}

public actor JSONUserProfileRepository: UserProfileRepository {
    private let configDirectory: URL
    private let fileAccessor: any FileAccessorProviding

    private var profilesDirectory: URL {
        configDirectory.appendingPathComponent("profiles", isDirectory: true)
    }

    private var activeProfileFile: URL {
        configDirectory.appendingPathComponent("active_profile.json")
    }

    public init(configDirectory: URL, fileAccessor: any FileAccessorProviding = DefaultFileAccessor()) {
        self.configDirectory = configDirectory
        self.fileAccessor = fileAccessor
    }

    private static func decodeProfile(from data: Data) async -> UserProfile? {
        let decoder = JSONDecoder()
        return try? decoder.decode(UserProfile.self, from: data)
    }

    private static func encodeProfile(_ profile: UserProfile) async -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(profile)
    }

    public func listProfiles() async -> [UserProfile] {
        try? fileAccessor.ensureDirectory(at: profilesDirectory)
        let urls = (try? fileAccessor.contentsOfDirectory(at: profilesDirectory)) ?? []
        var results: [UserProfile] = []
        for url in urls where url.pathExtension == "json" {
            guard let data = try? fileAccessor.read(from: url) else { continue }
            if let profile = await Self.decodeProfile(from: data) {
                results.append(profile)
            }
        }
        return results.sorted { $0.createdAt > $1.createdAt }
    }

    public func profile(id: String) async -> UserProfile? {
        guard Self.isSafeId(id) else { return nil }
        let url = profilesDirectory.appendingPathComponent("\(id).json")
        guard let data = try? fileAccessor.read(from: url) else { return nil }
        return await Self.decodeProfile(from: data)
    }

    public func save(_ profile: UserProfile) async throws {
        guard Self.isSafeId(profile.id) else {
            throw SwimNotePersistenceError.invalidDate(profile.id)
        }
        try fileAccessor.ensureDirectory(at: profilesDirectory)
        let url = profilesDirectory.appendingPathComponent("\(profile.id).json")
        guard let data = await Self.encodeProfile(profile) else {
            throw SwimNotePersistenceError.encodingFailed
        }
        try fileAccessor.write(data, to: url)
    }

    public func delete(id: String) async throws {
        guard Self.isSafeId(id) else {
            throw SwimNotePersistenceError.invalidDate(id)
        }
        let url = profilesDirectory.appendingPathComponent("\(id).json")
        try fileAccessor.remove(at: url)
        if await activeProfileId() == id {
            try await setActiveProfile(id: "")
        }
    }

    public func activeProfileId() async -> String? {
        guard let data = try? fileAccessor.read(from: activeProfileFile) else { return nil }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = json["activeProfileId"] as? String,
              !id.isEmpty else { return nil }
        return id
    }

    public func setActiveProfile(id: String) async throws {
        let json: [String: Any] = ["activeProfileId": id.isEmpty ? "" : id]
        let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted])
        try fileAccessor.ensureDirectory(at: configDirectory)
        try fileAccessor.write(data, to: activeProfileFile)
    }

    private nonisolated static func isSafeId(_ id: String) -> Bool {
        !id.isEmpty
            && id.count <= 64
            && !id.contains("/")
            && !id.contains("\\")
            && !id.contains("..")
    }
}