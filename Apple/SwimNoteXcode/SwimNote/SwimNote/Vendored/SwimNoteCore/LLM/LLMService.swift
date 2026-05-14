import Foundation
import OSLog
import os

private let llmLog = Logger(subsystem: "com.swimnote.llm", category: "LLMService")

/// Native Anthropic was removed in P2-2A; reach Claude through `.openRouter`
/// instead. Persisted configs that still say `provider: "anthropic"` are
/// migrated to `.openRouter` in `LLMConfigurationStore.load()`.
public enum LLMProvider: String, Codable, Hashable, Sendable, CaseIterable {
    case openAI = "openai"
    case openRouter = "openrouter"
    case openAICompatible = "openai_compatible"

    public var defaultBaseURL: URL? {
        switch self {
        case .openAI: return URL(string: "https://api.openai.com/v1")
        case .openRouter: return URL(string: "https://openrouter.ai/api/v1")
        case .openAICompatible: return nil
        }
    }

    public var supportsToolCalling: Bool {
        switch self {
        case .openAI, .openRouter: return true
        case .openAICompatible: return true // Depends on endpoint, but DashScope supports it
        }
    }

    public var displayName: String {
        switch self {
        case .openAI: return "OpenAI"
        case .openRouter: return "OpenRouter"
        case .openAICompatible: return "OpenAI Compatible"
        }
    }

    public var suggestedModels: [String] {
        switch self {
        case .openAI: return ["gpt-4o", "gpt-4o-mini"]
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
    /// Transport-level retries for a single HTTP request — distinct from
    /// `maxToolIterations`, which counts agent-style tool rounds. P2-2B wired
    /// this through `withTransportRetry` in `OpenAIClient.completeWithTools`.
    public var maxRetries: Int
    /// How many tool-calling rounds the agent loop may take per call. Default 8
    /// matches typical OpenAI agent budgets. Call sites can still override via
    /// `ToolCallingConversation.run(maxIterations:)`.
    public var maxToolIterations: Int

    public init(
        provider: LLMProvider,
        apiKeyReference: String,
        baseURL: URL? = nil,
        modelName: String,
        timeoutSeconds: TimeInterval = 60,
        maxRetries: Int = 3,
        maxToolIterations: Int = 8
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
        self.maxToolIterations = maxToolIterations
    }

    private enum CodingKeys: String, CodingKey {
        case provider, apiKeyReference, baseURL, modelName, timeoutSeconds, maxRetries, maxToolIterations
    }

    public nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        provider = try container.decode(LLMProvider.self, forKey: .provider)
        apiKeyReference = try container.decode(String.self, forKey: .apiKeyReference)
        baseURL = try container.decodeIfPresent(URL.self, forKey: .baseURL)
        modelName = try container.decode(String.self, forKey: .modelName)
        timeoutSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .timeoutSeconds) ?? 60
        maxRetries = try container.decodeIfPresent(Int.self, forKey: .maxRetries) ?? 3
        maxToolIterations = try container.decodeIfPresent(Int.self, forKey: .maxToolIterations) ?? 8
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
        try container.encode(maxToolIterations, forKey: .maxToolIterations)
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
    /// Per-request OpenAI `max_tokens` cap. When `nil`, the client falls back
    /// to a generous default. Setting per phase (outline 2048, detail 4096,
    /// dryland 1536) cuts cost without hurting throughput. Added in P2-2C.
    public var maxTokens: Int?

    public init(
        systemRole: String,
        prompt: String,
        temperature: Double = 0.2,
        tools: [Tool]? = nil,
        toolChoice: ToolChoice? = nil,
        messages: [ConversationMessage]? = nil,
        maxTokens: Int? = nil
    ) {
        self.systemRole = systemRole
        self.prompt = prompt
        self.temperature = temperature
        self.tools = tools
        self.toolChoice = toolChoice
        self.messages = messages
        self.maxTokens = maxTokens
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(systemRole)
        hasher.combine(prompt)
        hasher.combine(temperature)
        hasher.combine(maxTokens)
        // Skip tools, toolChoice, messages for hashing
    }

    public static func == (lhs: LLMRequest, rhs: LLMRequest) -> Bool {
        lhs.systemRole == rhs.systemRole &&
        lhs.prompt == rhs.prompt &&
        lhs.temperature == rhs.temperature &&
        lhs.maxTokens == rhs.maxTokens
    }
}

public protocol LLMClient: Sendable {
    func complete(_ request: LLMRequest, configuration: LLMConfiguration, apiKey: String) async throws -> String
    func completeWithTools(_ request: LLMRequest, configuration: LLMConfiguration, apiKey: String) async throws -> LLMResponse
}

public struct LLMResponse: Sendable {
    public var content: String?
    public var toolCalls: [ToolCall]?
    public var reasoningContent: String?  // DeepSeek V4 thinking mode returns this

    public init(content: String? = nil, toolCalls: [ToolCall]? = nil, reasoningContent: String? = nil) {
        self.content = content
        self.toolCalls = toolCalls
        self.reasoningContent = reasoningContent
    }

    public var hasToolCalls: Bool {
        // Avoid force-unwrap so a future refactor can't turn this into a
        // crash by accident. `?.isEmpty == false` is the standard idiom for
        // "non-nil and non-empty" on optional collections.
        toolCalls?.isEmpty == false
    }
}

// MARK: - Transport-level retry (P2-2B)

/// Result of a single transport attempt — either a usable HTTP response or a
/// retry-worthy classification. Non-retry-worthy errors (e.g. URLError that
/// isn't transient) are thrown out of the closure directly.
private enum TransportRetryDecision {
    case success(Data, HTTPURLResponse)
    case retryHTTP(Int)
    case retryURLError(URLError)
}

/// Wrap a single HTTP attempt in exponential backoff with jitter.
///
/// Retries on 429, 5xx HTTP responses, and transient `URLError` codes
/// (timeout, network connection lost, DNS, cannot connect to host, etc.).
/// Backoff: `min(30s, 0.5s * 2^attempt) + uniform(0..0.5s)`.
///
/// `maxRetries` is *additional* attempts after the first call (so
/// `maxRetries=3` -> up to 4 total attempts). After exhaustion, throws the
/// classified error so callers see the final status code or URLError.
private func withTransportRetry(
    maxRetries: Int,
    attempt: () async throws -> TransportRetryDecision
) async throws -> (Data, HTTPURLResponse) {
    var lastHTTPCode: Int?
    var lastURLError: URLError?

    let totalAttempts = max(0, maxRetries) + 1
    for attemptIndex in 0..<totalAttempts {
        let decision: TransportRetryDecision
        do {
            decision = try await attempt()
        } catch let urlError as URLError where transportIsTransient(urlError: urlError) {
            // The closure may also throw transient URLErrors directly (e.g. if
            // the caller doesn't classify them itself). Treat as retryable.
            lastURLError = urlError
            if attemptIndex == totalAttempts - 1 {
                throw urlError
            }
            try await transportSleepForBackoff(attemptIndex: attemptIndex)
            continue
        }

        switch decision {
        case .success(let data, let response):
            return (data, response)
        case .retryHTTP(let code):
            lastHTTPCode = code
            if attemptIndex == totalAttempts - 1 {
                throw LLMServiceError.httpError(code)
            }
            try await transportSleepForBackoff(attemptIndex: attemptIndex)
        case .retryURLError(let urlError):
            lastURLError = urlError
            if attemptIndex == totalAttempts - 1 {
                throw urlError
            }
            try await transportSleepForBackoff(attemptIndex: attemptIndex)
        }
    }

    // Should be unreachable; the loop body throws on the last attempt.
    if let code = lastHTTPCode {
        throw LLMServiceError.httpError(code)
    }
    if let urlError = lastURLError {
        throw urlError
    }
    throw LLMServiceError.invalidResponse
}

/// `URLError` codes worth retrying — anything that's "the network just
/// flickered" or "the server hung up" rather than a config/auth failure.
private func transportIsTransient(urlError: URLError) -> Bool {
    switch urlError.code {
    case .timedOut,
         .cannotFindHost,
         .cannotConnectToHost,
         .networkConnectionLost,
         .dnsLookupFailed,
         .notConnectedToInternet,
         .resourceUnavailable,
         .secureConnectionFailed:
        return true
    default:
        return false
    }
}

private func transportSleepForBackoff(attemptIndex: Int) async throws {
    let base: Double = 0.5
    let cap: Double = 30.0
    let exp = min(cap, base * pow(2.0, Double(attemptIndex)))
    let jitter = Double.random(in: 0...0.5)
    let delaySeconds = min(cap, exp + jitter)
    let nanoseconds = UInt64(delaySeconds * 1_000_000_000)
    try await Task.sleep(nanoseconds: nanoseconds)
}

/// P2-2E: log a sanitized summary of the outgoing LLM request instead of
/// the full body. Full prompts can contain personal training notes, profile
/// names, and goals — none of that belongs in unified logs by default.
///
/// Default (release + debug): url, body byte count, ~token estimate, first
/// 200 chars of the body. Token estimate is bytes/4, the same back-of-envelope
/// OpenAI uses in its docs; close enough for cost dashboards, never used for
/// billing.
///
/// Opt-in: in DEBUG only, set `UserDefaults.standard.set(true, forKey: "llm.debug.fullBodies")`
/// from the simulator console to dump full bodies. Never enabled implicitly.
private func logSanitizedRequest(url: URL, bodyData: Data, body: [String: Any]) {
    let byteCount = bodyData.count
    let estimatedTokens = byteCount / 4
    let previewBytes = bodyData.prefix(200)
    let preview = String(data: previewBytes, encoding: .utf8) ?? "<non-utf8>"

    #if DEBUG
    let dumpFull = UserDefaults.standard.bool(forKey: "llm.debug.fullBodies")
    if dumpFull {
        llmLog.info("LLM Request to \(url, privacy: .public): \(body)")
        return
    }
    #endif

    llmLog.info(
        "LLM Request to \(url, privacy: .public) bytes=\(byteCount) ~tokens=\(estimatedTokens) preview=\(preview, privacy: .public)"
    )
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

        // P2-2C: per-request cap if the caller supplied one (outline 2048,
        // detail 4096, dryland 1536, etc.); fall back to the historical 8192
        // for callers that didn't opt in yet.
        var body: [String: Any] = [
            "model": configuration.modelName,
            "messages": messagesArray,
            "temperature": request.temperature,
            "max_tokens": request.maxTokens ?? 8192
        ]

        // Note: response_format json_object can interfere with tool calling, so we don't use it
        // The prompts explicitly request JSON output format

        if let tools = request.tools {
            body["tools"] = tools.map { tool -> [String: Any] in
                var functionDict: [String: Any] = [
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
                        "required": tool.function.parameters.required ?? [],
                        "additionalProperties": tool.function.parameters.additionalProperties ?? false
                    ] as [String: Any]
                ]
                // DeepSeek V4 strict mode
                if let strict = tool.function.strict {
                    functionDict["strict"] = strict
                }
                return [
                    "type": tool.type,
                    "function": functionDict
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

        let bodyData = try JSONSerialization.data(withJSONObject: body)
        httpRequest.httpBody = bodyData
        logSanitizedRequest(url: url, bodyData: bodyData, body: body)

        // P2-2B: transport retries with exponential backoff + jitter.
        // The retry helper decides whether to retry based on classification
        // returned from the closure; non-retryable HTTP errors (4xx other than
        // 429) and decoded API error bodies throw straight out.
        let httpRequestForRetry = httpRequest
        let (data, httpResponse) = try await withTransportRetry(maxRetries: configuration.maxRetries) {
            do {
                let (responseData, response) = try await URLSession.shared.data(for: httpRequestForRetry)
                guard let httpResponse = response as? HTTPURLResponse else {
                    llmLog.error("Invalid response - not HTTPURLResponse")
                    throw LLMServiceError.invalidResponse
                }
                let status = httpResponse.statusCode
                if status == 429 || (500...599).contains(status) {
                    #if DEBUG
                    print("🔧 Transient HTTP \(status); will retry")
                    #endif
                    return .retryHTTP(status)
                }
                return .success(responseData, httpResponse)
            } catch let urlError as URLError where transportIsTransient(urlError: urlError) {
                return .retryURLError(urlError)
            }
        }

        llmLog.info("LLM Response status: \(httpResponse.statusCode)")

        // Debug: Log raw response for troubleshooting
        #if DEBUG
        if let rawString = String(data: data, encoding: .utf8) {
            print("🔧 Raw API response (first 500 chars): \(String(rawString.prefix(500)))")
        }
        #endif

        guard httpResponse.statusCode == 200 else {
            // Non-retryable error path: parse a server-supplied message if we
            // can so the user sees something better than just "503".
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
            // Log response body for non-200 errors
            #if DEBUG
            if let rawString = String(data: data, encoding: .utf8) {
                print("🔧 Error response body: \(rawString)")
            }
            #endif
            throw LLMServiceError.httpError(httpResponse.statusCode)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any] else {
            #if DEBUG
            print("🔧 Failed to parse response: missing choices or message")
            #endif
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
            // Extract reasoning_content for DeepSeek V4 thinking mode round-trip
            let reasoningContent = message["reasoning_content"] as? String
            #if DEBUG
            if let reasoning = reasoningContent {
                print("🔧 Model reasoning: \(String(reasoning.prefix(200)))")
            }
            #endif
            return LLMResponse(content: nil, toolCalls: toolCalls, reasoningContent: reasoningContent)
        }

        // Return text content (may be empty string)
        let content = message["content"] as? String
        let reasoningContent = message["reasoning_content"] as? String

        #if DEBUG
        // Log reasoning if present and content is empty
        if content == nil || content?.isEmpty == true {
            if let reasoning = reasoningContent {
                print("🔧 Model reasoning (no content): \(String(reasoning.prefix(200)))")
            }
        }
        #endif

        // Return response - content may be nil or empty
        return LLMResponse(content: content, toolCalls: nil, reasoningContent: reasoningContent)
    }
}

// AnthropicClient (native Claude) deleted in P2-2A. Use `.openRouter` to
// reach Anthropic models via `OpenAIClient` over the OpenRouter proxy.

public enum LLMServiceError: Error, Equatable {
    case invalidResponse
    case httpError(Int)
    case apiError(String)
    case maxIterationsReached
}

public protocol SecureCredentialStore: Sendable {
    func save(_ secret: String, for account: String) throws
    func load(account: String) throws -> String?
    func delete(account: String) throws
}

/// Lock-backed in-memory store. The previous `@unchecked Sendable` over a
/// bare `Dictionary` would tear (and could crash) under concurrent writes
/// from `SwimNoteAppModel` + multiple parallel `PlanningView` tasks. We stay
/// `final class @unchecked Sendable` so the protocol can keep its sync
/// signatures (the alternative — actor — would force `async` through every
/// LLM call site, which is more churn than the bug warrants). The unchecked
/// claim is now backed by `os_unfair_lock` around every read and write.
public final class InMemoryCredentialStore: SecureCredentialStore, @unchecked Sendable {
    private var secrets: [String: String] = [:]
    private let lock = OSAllocatedUnfairLock()

    public init() {}

    public func save(_ secret: String, for account: String) throws {
        lock.lock()
        defer { lock.unlock() }
        secrets[account] = secret
    }

    public func load(account: String) throws -> String? {
        lock.lock()
        defer { lock.unlock() }
        return secrets[account]
    }

    public func delete(account: String) throws {
        lock.lock()
        defer { lock.unlock() }
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
