import Foundation

public enum LLMProvider: String, Codable, Hashable, Sendable, CaseIterable {
    case openAI = "openai"
    case anthropic
    case openAICompatible = "openai_compatible"
}

public struct LLMConfiguration: Codable, Hashable, Sendable {
    public var provider: LLMProvider
    public var apiKeyReference: String
    public var baseURL: URL?
    public var modelName: String
    public var timeoutSeconds: TimeInterval
    public var maxRetries: Int

    public init(
        provider: LLMProvider,
        apiKeyReference: String,
        baseURL: URL? = nil,
        modelName: String,
        timeoutSeconds: TimeInterval = 60,
        maxRetries: Int = 3
    ) throws {
        if let baseURL, baseURL.scheme?.lowercased() != "https" {
            throw LLMConfigurationError.insecureBaseURL
        }
        self.provider = provider
        self.apiKeyReference = apiKeyReference
        self.baseURL = baseURL
        self.modelName = modelName
        self.timeoutSeconds = timeoutSeconds
        self.maxRetries = maxRetries
    }
}

public enum LLMConfigurationError: Error, Equatable {
    case insecureBaseURL
}

public struct LLMRequest: Codable, Hashable, Sendable {
    public var systemRole: String
    public var prompt: String
    public var temperature: Double

    public init(systemRole: String, prompt: String, temperature: Double = 0.2) {
        self.systemRole = systemRole
        self.prompt = prompt
        self.temperature = temperature
    }
}

public protocol LLMClient: Sendable {
    func complete(_ request: LLMRequest, configuration: LLMConfiguration) async throws -> String
}

public struct CoachingPromptBuilder: Sendable {
    public init() {}

    public func request(for node: TechniqueTreeNode) -> LLMRequest {
        let revisitLine = node.revisit ? "Note: This is a fundamental technique to practice regularly." : ""
        let prompt = """
        You are an expert swimming coach. A swimmer wants to focus on "\(node.name)".

        Technique: \(node.description)
        Level: \(node.level) (1=easiest)
        \(revisitLine)

        Give 3-4 bullet-point tips. Each bullet must be ONE short sentence (max 10 words).
        Focus on: body position, timing, or common mistake to avoid.

        Output ONLY bullets, no intro/outro. Format:
        • Tip one
        • Tip two
        • Tip three
        """

        return LLMRequest(systemRole: "expert_swimming_coach", prompt: prompt)
    }
}

public struct GoalSuggestionPromptBuilder: Sendable {
    public init() {}

    public func request(for note: TrainingNote, recentNotes: [TrainingNote]) -> LLMRequest {
        let history = recentNotes
            .prefix(7)
            .map { "\($0.date): \($0.notes)" }
            .joined(separator: "\n")

        let prompt = """
        You are an expert swimming coach. Suggest focused training goals.

        Today's notes:
        \(note.notes.isEmpty ? "No notes yet." : note.notes)

        Recent training:
        \(history.isEmpty ? "No recent notes." : history)

        Return 3 concise goals with measurable cues.
        """

        return LLMRequest(systemRole: "expert_swimming_coach", prompt: prompt)
    }
}

public protocol SecureCredentialStore: Sendable {
    func save(_ secret: String, for account: String) throws
    func load(account: String) throws -> String?
    func delete(account: String) throws
}

public final class InMemoryCredentialStore: SecureCredentialStore, @unchecked Sendable {
    private var secrets: [String: String] = [:]

    public init() {}

    public func save(_ secret: String, for account: String) throws {
        secrets[account] = secret
    }

    public func load(account: String) throws -> String? {
        secrets[account]
    }

    public func delete(account: String) throws {
        secrets[account] = nil
    }
}

#if canImport(Security)
import Security

public struct KeychainCredentialStore: SecureCredentialStore {
    private let service: String

    public init(service: String = "SwimNote.LLM") {
        self.service = service
    }

    public func save(_ secret: String, for account: String) throws {
        try delete(account: account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: Data(secret.utf8)
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw CredentialStoreError.keychainStatus(status)
        }
    }

    public func load(account: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw CredentialStoreError.keychainStatus(status)
        }
        return String(data: data, encoding: .utf8)
    }

    public func delete(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CredentialStoreError.keychainStatus(status)
        }
    }
}
#endif

public enum CredentialStoreError: Error, Equatable {
    case keychainStatus(OSStatus)
}
