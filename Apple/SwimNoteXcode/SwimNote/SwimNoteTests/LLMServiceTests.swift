//
//  LLMServiceTests.swift
//  SwimNoteTests
//
//  Tests for LLM configuration, request building, and response parsing
//

import Testing
import Foundation
@testable import SwimNote

struct LLMServiceTests {

    // MARK: - LLMProvider Tests

    @Test("LLMProvider has correct display names")
    func llmProviderDisplayNames() {
        #expect(LLMProvider.openAI.displayName == "OpenAI")
        #expect(LLMProvider.openRouter.displayName == "OpenRouter")
        #expect(LLMProvider.openAICompatible.displayName == "OpenAI Compatible")
    }

    @Test("LLMProvider has correct default base URLs")
    func llmProviderDefaultURLs() {
        #expect(LLMProvider.openAI.defaultBaseURL?.absoluteString == "https://api.openai.com/v1")
        #expect(LLMProvider.openRouter.defaultBaseURL?.absoluteString == "https://openrouter.ai/api/v1")
        #expect(LLMProvider.openAICompatible.defaultBaseURL == nil)
    }

    @Test("LLMProvider supports tool calling")
    func llmProviderToolCalling() {
        #expect(LLMProvider.openAI.supportsToolCalling == true)
        #expect(LLMProvider.openRouter.supportsToolCalling == true)
        #expect(LLMProvider.openAICompatible.supportsToolCalling == true)
    }

    @Test("LLMProvider suggested models are non-empty")
    func llmProviderSuggestedModels() {
        #expect(LLMProvider.openAI.suggestedModels.isEmpty == false)
        #expect(LLMProvider.openRouter.suggestedModels.isEmpty == false)
    }

    @Test("LLMProvider.allCases excludes the deleted .anthropic case (P2-2A)")
    func llmProviderAllCasesExcludesAnthropic() {
        let raws = LLMProvider.allCases.map(\.rawValue)
        #expect(raws.contains("anthropic") == false)
    }

    // MARK: - LLMConfiguration Tests

    @Test("LLMConfiguration can be created with all parameters")
    func llmConfigurationCreation() throws {
        let config = try LLMConfiguration(
            provider: .openAI,
            apiKeyReference: "test-key",
            baseURL: URL(string: "https://api.example.com/v1"),
            modelName: "gpt-4o",
            timeoutSeconds: 60,
            maxRetries: 3
        )

        #expect(config.provider == .openAI)
        #expect(config.apiKeyReference == "test-key")
        #expect(config.modelName == "gpt-4o")
        #expect(config.timeoutSeconds == 60)
        #expect(config.maxRetries == 3)
    }

    @Test("LLMConfiguration rejects insecure URLs")
    func llmConfigurationInsecureURL() {
        #expect(throws: LLMConfigurationError.insecureBaseURL) {
            try LLMConfiguration(
                provider: .openAI,
                apiKeyReference: "test",
                baseURL: URL(string: "http://api.example.com/v1"),  // http, not https
                modelName: "gpt-4o"
            )
        }
    }

    @Test("LLMConfiguration uses default timeout and retries")
    func llmConfigurationDefaults() throws {
        let config = try LLMConfiguration(
            provider: .openAI,
            apiKeyReference: "test",
            modelName: "gpt-4o"
        )

        #expect(config.timeoutSeconds == 60)
        #expect(config.maxRetries == 3)
        #expect(config.maxToolIterations == 8) // P2-2B
        #expect(config.baseURL == nil)
    }

    @Test("LLMConfiguration decodes legacy blob without maxToolIterations key (P2-2B)")
    func llmConfigurationDecodesLegacyWithoutMaxToolIterations() throws {
        // Legacy blob — what UserDefaults held before P2-2B.
        let legacyJSON = """
        {
          "provider": "openai",
          "apiKeyReference": "llm-openai",
          "modelName": "gpt-4o",
          "timeoutSeconds": 60,
          "maxRetries": 3
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(LLMConfiguration.self, from: legacyJSON)
        #expect(decoded.maxToolIterations == 8)
    }

    @Test("LLMConfiguration is Codable")
    func llmConfigurationCodable() throws {
        let config = try LLMConfiguration(
            provider: .openAI,
            apiKeyReference: "test",
            modelName: "gpt-4o"
        )

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(LLMConfiguration.self, from: data)

        #expect(decoded.provider == config.provider)
        #expect(decoded.apiKeyReference == config.apiKeyReference)
        #expect(decoded.modelName == config.modelName)
    }

    // MARK: - LLMRequest Tests

    @Test("LLMRequest can be created with basic parameters")
    func llmRequestBasic() {
        let request = LLMRequest(
            systemRole: "You are a coach",
            prompt: "Give me advice",
            temperature: 0.5
        )

        #expect(request.systemRole == "You are a coach")
        #expect(request.prompt == "Give me advice")
        #expect(request.temperature == 0.5)
        #expect(request.tools == nil)
        #expect(request.toolChoice == nil)
    }

    @Test("LLMRequest can include tools")
    func llmRequestWithTools() {
        let tools = ResourcesNavigationTools.all
        let request = LLMRequest(
            systemRole: "Coach",
            prompt: "Help me",
            tools: tools,
            toolChoice: .auto
        )

        #expect(request.tools?.count == 4)
        #expect(request.toolChoice != nil)
    }

    @Test("LLMRequest is Hashable")
    func llmRequestHashable() {
        let request1 = LLMRequest(systemRole: "Coach", prompt: "Help", temperature: 0.5)
        let request2 = LLMRequest(systemRole: "Coach", prompt: "Help", temperature: 0.5)
        let request3 = LLMRequest(systemRole: "Coach", prompt: "Different", temperature: 0.5)

        #expect(request1 == request2)
        #expect(request1 != request3)
    }

    // P2-2C: ensure maxTokens is wired through the value type and participates in equality.
    @Test("LLMRequest carries optional maxTokens (P2-2C)")
    func llmRequestMaxTokens() {
        let defaultRequest = LLMRequest(systemRole: "Coach", prompt: "Help")
        #expect(defaultRequest.maxTokens == nil)

        let outline = LLMRequest(systemRole: "Coach", prompt: "Help", maxTokens: 2048)
        let detail = LLMRequest(systemRole: "Coach", prompt: "Help", maxTokens: 4096)
        let dryland = LLMRequest(systemRole: "Coach", prompt: "Help", maxTokens: 1536)

        #expect(outline.maxTokens == 2048)
        #expect(detail.maxTokens == 4096)
        #expect(dryland.maxTokens == 1536)

        // maxTokens differences must propagate through Equatable so callers can't accidentally
        // share request hashes when their token caps diverge.
        let outlineTwin = LLMRequest(systemRole: "Coach", prompt: "Help", maxTokens: 2048)
        #expect(outline == outlineTwin)
        #expect(outline != detail)
    }

    // MARK: - LLMResponse Tests

    @Test("LLMResponse with content only")
    func llmResponseContentOnly() {
        let response = LLMResponse(content: "Hello!", toolCalls: nil)

        #expect(response.content == "Hello!")
        #expect(response.hasToolCalls == false)
    }

    @Test("LLMResponse with tool calls only")
    func llmResponseToolCallsOnly() {
        let toolCall = ToolCall(
            id: "call_1",
            function: ToolCallFunction(name: "test_tool", arguments: "{}")
        )
        let response = LLMResponse(content: nil, toolCalls: [toolCall])

        #expect(response.content == nil)
        #expect(response.hasToolCalls == true)
    }

    @Test("LLMResponse with both content and tool calls")
    func llmResponseBoth() {
        let toolCall = ToolCall(id: "call_1", function: ToolCallFunction(name: "test", arguments: "{}"))
        let response = LLMResponse(content: "Some text", toolCalls: [toolCall])

        #expect(response.content == "Some text")
        #expect(response.hasToolCalls == true)
    }

    @Test("LLMResponse empty tool calls array means no tool calls")
    func llmResponseEmptyToolCalls() {
        let response = LLMResponse(content: nil, toolCalls: [])

        #expect(response.hasToolCalls == false)
    }

    // MARK: - LLMServiceError Tests

    @Test("LLMServiceError is Equatable")
    func llmServiceErrorEquatable() {
        #expect(LLMServiceError.invalidResponse == LLMServiceError.invalidResponse)
        #expect(LLMServiceError.httpError(404) == LLMServiceError.httpError(404))
        #expect(LLMServiceError.httpError(404) != LLMServiceError.httpError(500))
        #expect(LLMServiceError.apiError("test") == LLMServiceError.apiError("test"))
        #expect(LLMServiceError.apiError("test") != LLMServiceError.apiError("other"))
    }

    // MARK: - OpenAIClient Request Building Tests

    @Test("OpenAIClient baseURL uses config or provider default")
    func openAIClientBaseURL() throws {
        let client = OpenAIClient()

        // With explicit baseURL
        let config1 = try LLMConfiguration(
            provider: .openAI,
            apiKeyReference: "test",
            baseURL: URL(string: "https://custom.api.com/v1"),
            modelName: "gpt-4o"
        )
        #expect(client.baseURL(for: config1).absoluteString == "https://custom.api.com/v1")

        // Without explicit baseURL (uses provider default)
        let config2 = try LLMConfiguration(
            provider: .openAI,
            apiKeyReference: "test",
            modelName: "gpt-4o"
        )
        #expect(client.baseURL(for: config2).absoluteString == "https://api.openai.com/v1")
    }

    // AnthropicClient request-building tests deleted in P2-2A; the type no
    // longer exists. Claude is reachable through OpenRouter via OpenAIClient.

    // MARK: - Credential Store Tests

    @Test("InMemoryCredentialStore works correctly")
    func inMemoryCredentialStore() throws {
        let store = InMemoryCredentialStore()

        // Save
        try store.save("secret123", for: "account1")

        // Load
        let loaded = try store.load(account: "account1")
        #expect(loaded == "secret123")

        // Delete
        try store.delete(account: "account1")
        let afterDelete = try store.load(account: "account1")
        #expect(afterDelete == nil)
    }

    @Test("InMemoryCredentialStore can save multiple accounts")
    func inMemoryCredentialStoreMultiple() throws {
        let store = InMemoryCredentialStore()

        try store.save("key1", for: "account1")
        try store.save("key2", for: "account2")

        #expect(try store.load(account: "account1") == "key1")
        #expect(try store.load(account: "account2") == "key2")
    }

    @Test("InMemoryCredentialStore overwrites existing account")
    func inMemoryCredentialStoreOverwrite() throws {
        let store = InMemoryCredentialStore()

        try store.save("old", for: "account1")
        try store.save("new", for: "account1")

        #expect(try store.load(account: "account1") == "new")
    }

    /// P0-1F: 200 racing tasks must not crash and must converge to a
    /// well-defined value. Pre-fix this exercised an unsynchronized Dictionary
    /// behind `@unchecked Sendable` — undefined behaviour. The new lock-backed
    /// store keeps every save/load atomic.
    @Test("InMemoryCredentialStore is safe under concurrent load")
    func inMemoryCredentialStoreConcurrent() async throws {
        let store = InMemoryCredentialStore()
        let account = "race-account"

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<200 {
                group.addTask {
                    try? store.save("value-\(i)", for: account)
                    _ = try? store.load(account: account)
                }
            }
        }

        // The exact final value is non-deterministic (last writer wins), but
        // it must be one of the values we wrote and must not crash on load.
        let final = try store.load(account: account)
        try #require(final != nil)
        #expect(final?.hasPrefix("value-") == true)
    }

    // MARK: - LLMResponse.hasToolCalls

    @Test("LLMResponse.hasToolCalls handles nil, empty, and populated cases without crashing")
    func llmResponseHasToolCalls() {
        // nil → false (was the crash path; force-unwrap removed in P0-1E)
        let nilCase = LLMResponse(content: "hi", toolCalls: nil)
        #expect(nilCase.hasToolCalls == false)

        let emptyCase = LLMResponse(content: "hi", toolCalls: [])
        #expect(emptyCase.hasToolCalls == false)

        let populated = LLMResponse(
            content: nil,
            toolCalls: [ToolCall(id: "1", function: ToolCallFunction(name: "noop", arguments: "{}"))]
        )
        #expect(populated.hasToolCalls == true)
    }
}