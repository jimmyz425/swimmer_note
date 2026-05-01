import Foundation
import OSLog

private let llmLog = Logger(subsystem: "com.swimnote.llm", category: "LLMService")

public enum LLMProvider: String, Codable, Hashable, Sendable, CaseIterable {
    case openAI = "openai"
    case anthropic
    case openRouter = "openrouter"
    case openAICompatible = "openai_compatible"

    public var defaultBaseURL: URL? {
        switch self {
        case .openAI: return URL(string: "https://api.openai.com/v1")
        case .anthropic: return URL(string: "https://api.anthropic.com/v1")
        case .openRouter: return URL(string: "https://openrouter.ai/api/v1")
        case .openAICompatible: return nil
        }
    }

    public var supportsToolCalling: Bool {
        switch self {
        case .openAI, .anthropic, .openRouter: return true
        case .openAICompatible: return true // Depends on endpoint, but DashScope supports it
        }
    }

    public var displayName: String {
        switch self {
        case .openAI: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .openRouter: return "OpenRouter"
        case .openAICompatible: return "OpenAI Compatible"
        }
    }

    public var suggestedModels: [String] {
        switch self {
        case .openAI: return ["gpt-4o", "gpt-4o-mini"]
        case .anthropic: return ["claude-sonnet-4-20250514", "claude-opus-4-20250514"]
        case .openRouter: return ["anthropic/claude-sonnet-4", "openai/gpt-4o-mini", "meta-llama/llama-3.1-70b-instruct"]
        case .openAICompatible: return ["custom-model"]
        }
    }
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

    private enum CodingKeys: String, CodingKey {
        case provider, apiKeyReference, baseURL, modelName, timeoutSeconds, maxRetries
    }

    public nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        provider = try container.decode(LLMProvider.self, forKey: .provider)
        apiKeyReference = try container.decode(String.self, forKey: .apiKeyReference)
        baseURL = try container.decodeIfPresent(URL.self, forKey: .baseURL)
        modelName = try container.decode(String.self, forKey: .modelName)
        timeoutSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .timeoutSeconds) ?? 60
        maxRetries = try container.decodeIfPresent(Int.self, forKey: .maxRetries) ?? 3
        if let baseURL, baseURL.scheme?.lowercased() != "https" {
            throw LLMConfigurationError.insecureBaseURL
        }
    }

    public nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(provider, forKey: .provider)
        try container.encode(apiKeyReference, forKey: .apiKeyReference)
        try container.encodeIfPresent(baseURL, forKey: .baseURL)
        try container.encode(modelName, forKey: .modelName)
        try container.encode(timeoutSeconds, forKey: .timeoutSeconds)
        try container.encode(maxRetries, forKey: .maxRetries)
    }
}

public enum LLMConfigurationError: Error, Equatable {
    case insecureBaseURL
}

public nonisolated struct LLMRequest: Hashable, Sendable {
    public var systemRole: String
    public var prompt: String
    public var temperature: Double
    public var tools: [Tool]?
    public var toolChoice: ToolChoice?
    public var messages: [ConversationMessage]?  // Full conversation history for tool calling

    public init(systemRole: String, prompt: String, temperature: Double = 0.2, tools: [Tool]? = nil, toolChoice: ToolChoice? = nil, messages: [ConversationMessage]? = nil) {
        self.systemRole = systemRole
        self.prompt = prompt
        self.temperature = temperature
        self.tools = tools
        self.toolChoice = toolChoice
        self.messages = messages
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(systemRole)
        hasher.combine(prompt)
        hasher.combine(temperature)
        // Skip tools, toolChoice, messages for hashing
    }

    public static func == (lhs: LLMRequest, rhs: LLMRequest) -> Bool {
        lhs.systemRole == rhs.systemRole &&
        lhs.prompt == rhs.prompt &&
        lhs.temperature == rhs.temperature
    }
}

public protocol LLMClient: Sendable {
    func complete(_ request: LLMRequest, configuration: LLMConfiguration, apiKey: String) async throws -> String
    func completeWithTools(_ request: LLMRequest, configuration: LLMConfiguration, apiKey: String) async throws -> LLMResponse
}

public struct LLMResponse: Sendable {
    public var content: String?
    public var toolCalls: [ToolCall]?

    public init(content: String? = nil, toolCalls: [ToolCall]? = nil) {
        self.content = content
        self.toolCalls = toolCalls
    }

    public var hasToolCalls: Bool {
        toolCalls != nil && !toolCalls!.isEmpty
    }
}

public struct OpenAIClient: LLMClient, Sendable {
    public init() {}

    public func baseURL(for configuration: LLMConfiguration) -> URL {
        configuration.baseURL ?? configuration.provider.defaultBaseURL ?? URL(string: "https://api.openai.com/v1")!
    }

    public func complete(_ request: LLMRequest, configuration: LLMConfiguration, apiKey: String) async throws -> String {
        let response = try await completeWithTools(request, configuration: configuration, apiKey: apiKey)
        if let content = response.content {
            return content
        }
        if response.hasToolCalls {
            throw LLMServiceError.apiError("Received tool calls when expecting text response")
        }
        throw LLMServiceError.invalidResponse
    }

    public func completeWithTools(_ request: LLMRequest, configuration: LLMConfiguration, apiKey: String) async throws -> LLMResponse {
        let url = baseURL(for: configuration).appendingPathComponent("chat/completions")

        var httpRequest = URLRequest(url: url)
        httpRequest.httpMethod = "POST"
        httpRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        httpRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        httpRequest.timeoutInterval = configuration.timeoutSeconds

        // OpenRouter requires additional headers
        if configuration.provider == .openRouter {
            httpRequest.setValue("SwimNote", forHTTPHeaderField: "X-Title")
            httpRequest.setValue("https://swimnote.app", forHTTPHeaderField: "HTTP-Referer")
        }

        // Use messages array if provided (for tool calling), otherwise build from system/prompt
        let messagesArray: [[String: Any]]
        if let providedMessages = request.messages, !providedMessages.isEmpty {
            messagesArray = providedMessages.map { $0.toOpenAIMessage() }
        } else {
            messagesArray = [
                ["role": "system", "content": request.systemRole],
                ["role": "user", "content": request.prompt]
            ]
        }

        var body: [String: Any] = [
            "model": configuration.modelName,
            "messages": messagesArray,
            "temperature": request.temperature,
            "max_tokens": 8192  // Increased for long training plan outputs
        ]

        // Note: OpenAI-compatible endpoint does NOT need result_format
        // Only the native DashScope SDK needs result_format: "message"

        if let tools = request.tools {
            body["tools"] = tools.map { tool -> [String: Any] in
                [
                    "type": tool.type,
                    "function": [
                        "name": tool.function.name,
                        "description": tool.function.description,
                        "parameters": [
                            "type": tool.function.parameters.type,
                            "properties": tool.function.parameters.properties.mapValues { prop -> [String: Any] in
                                var propDict: [String: Any] = ["type": prop.type]
                                if let desc = prop.description { propDict["description"] = desc }
                                if let enumVals = prop.enumValues { propDict["enum"] = enumVals }
                                return propDict
                            },
                            "required": tool.function.parameters.required ?? []
                        ] as [String: Any]
                    ]
                ]
            }
        }

        if let toolChoice = request.toolChoice {
            switch toolChoice {
            case .auto:
                body["tool_choice"] = "auto"
            case .none:
                body["tool_choice"] = "none"
            case .required:
                body["tool_choice"] = "required"
            case .specific(let name):
                body["tool_choice"] = ["type": "function", "function": ["name": name]]
            }
        }

        llmLog.info("LLM Request to \(url): \(body)")

        httpRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: httpRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            llmLog.error("Invalid response - not HTTPURLResponse")
            throw LLMServiceError.invalidResponse
        }

        llmLog.info("LLM Response status: \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw LLMServiceError.apiError(message)
            }
            // Try DashScope error format
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let code = errorJson["code"] as? String,
               let message = errorJson["message"] as? String {
                throw LLMServiceError.apiError("\(code): \(message)")
            }
            throw LLMServiceError.httpError(httpResponse.statusCode)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any] else {
            throw LLMServiceError.invalidResponse
        }

        // Check for tool calls first
        if let toolCallsJson = message["tool_calls"] as? [[String: Any]] {
            let toolCalls = toolCallsJson.compactMap { toolCallJson -> ToolCall? in
                guard let id = toolCallJson["id"] as? String,
                      let type = toolCallJson["type"] as? String,
                      let functionJson = toolCallJson["function"] as? [String: Any],
                      let name = functionJson["name"] as? String,
                      let arguments = functionJson["arguments"] as? String else {
                    return nil
                }
                return ToolCall(id: id, type: type, function: ToolCallFunction(name: name, arguments: arguments))
            }
            #if DEBUG
            // Log reasoning if present (qwen3.5-plus feature)
            if let reasoning = message["reasoning_content"] as? String {
                print("🔧 Model reasoning: \(String(reasoning.prefix(200)))")
            }
            #endif
            return LLMResponse(content: nil, toolCalls: toolCalls)
        }

        // Return text content (may be empty string)
        let content = message["content"] as? String

        #if DEBUG
        // Log reasoning if present and content is empty
        if content == nil || content?.isEmpty == true {
            if let reasoning = message["reasoning_content"] as? String {
                print("🔧 Model reasoning (no content): \(String(reasoning.prefix(200)))")
            }
        }
        #endif

        // Return response - content may be nil or empty
        return LLMResponse(content: content, toolCalls: nil)
    }
}

// MARK: - Anthropic Client (Claude)

public struct AnthropicClient: LLMClient, Sendable {
    public init() {}

    public func baseURL(for configuration: LLMConfiguration) -> URL {
        configuration.baseURL ?? URL(string: "https://api.anthropic.com/v1")!
    }

    public func complete(_ request: LLMRequest, configuration: LLMConfiguration, apiKey: String) async throws -> String {
        let response = try await completeWithTools(request, configuration: configuration, apiKey: apiKey)
        if let content = response.content {
            return content
        }
        if response.hasToolCalls {
            throw LLMServiceError.apiError("Received tool calls when expecting text response")
        }
        throw LLMServiceError.invalidResponse
    }

    public func completeWithTools(_ request: LLMRequest, configuration: LLMConfiguration, apiKey: String) async throws -> LLMResponse {
        let url = baseURL(for: configuration).appendingPathComponent("messages")

        var httpRequest = URLRequest(url: url)
        httpRequest.httpMethod = "POST"
        httpRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        httpRequest.setValue("x-api-key", forHTTPHeaderField: "x-api-key")
        httpRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        httpRequest.timeoutInterval = configuration.timeoutSeconds

        var body: [String: Any] = [
            "model": configuration.modelName,
            "max_tokens": 8192,  // Increased for long training plan outputs
            "system": request.systemRole,
            "messages": [
                ["role": "user", "content": request.prompt]
            ]
        ]

        // Anthropic uses different tool format
        if let tools = request.tools {
            body["tools"] = tools.map { tool -> [String: Any] in
                [
                    "name": tool.function.name,
                    "description": tool.function.description,
                    "input_schema": [
                        "type": tool.function.parameters.type,
                        "properties": tool.function.parameters.properties.mapValues { prop -> [String: Any] in
                            var propDict: [String: Any] = ["type": prop.type]
                            if let desc = prop.description { propDict["description"] = desc }
                            if let enumVals = prop.enumValues { propDict["enum"] = enumVals }
                            return propDict
                        },
                        "required": tool.function.parameters.required ?? []
                    ] as [String: Any]
                ]
            }
        }

        httpRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: httpRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMServiceError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw LLMServiceError.apiError(message)
            }
            throw LLMServiceError.httpError(httpResponse.statusCode)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let contentBlocks = json["content"] as? [[String: Any]] else {
            throw LLMServiceError.invalidResponse
        }

        // Check for tool use blocks
        let toolUseBlocks = contentBlocks.filter { ($0["type"] as? String) == "tool_use" }
        if !toolUseBlocks.isEmpty {
            let toolCalls = toolUseBlocks.compactMap { block -> ToolCall? in
                guard let id = block["id"] as? String,
                      let name = block["name"] as? String,
                      let input = block["input"] as? [String: Any] else {
                    return nil
                }
                let arguments = (try? JSONSerialization.data(withJSONObject: input)) ?? Data()
                let argumentsString = String(data: arguments, encoding: .utf8) ?? "{}"
                return ToolCall(id: id, type: "tool_use", function: ToolCallFunction(name: name, arguments: argumentsString))
            }
            return LLMResponse(content: nil, toolCalls: toolCalls)
        }

        // Get text content
        let textBlocks = contentBlocks.filter { ($0["type"] as? String) == "text" }
        let content = textBlocks.compactMap { $0["text"] as? String }.joined(separator: "\n")
        return LLMResponse(content: content, toolCalls: nil)
    }
}

public enum LLMServiceError: Error, Equatable {
    case invalidResponse
    case httpError(Int)
    case apiError(String)
    case maxIterationsReached
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

public enum CredentialStoreError: Error, Equatable, LocalizedError {
    case keychainStatus(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .keychainStatus(let status):
            return "Keychain error (code \(status)): \(keychainErrorDescription(status))"
        }
    }

    private func keychainErrorDescription(_ status: OSStatus) -> String {
        switch status {
        case -50: return "Invalid parameter"
        case -25229: return "Access denied"
        case -25300: return "Item not found"
        case -25299: return "Authentication failed"
        case -25298: return "Duplicate item"
        case 1: return "Unimplemented"
        case 2: return "Success (unexpected)"
        case 3: return "Bad attributes - keychain item format is invalid"
        case 4: return "Bad parameter"
        case 5: return "Allocate failed"
        case -1: return "Unspecified error"
        default: return "Unknown error"
        }
    }
}
