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
        #expect(LLMProvider.anthropic.displayName == "Anthropic")
        #expect(LLMProvider.openRouter.displayName == "OpenRouter")
        #expect(LLMProvider.openAICompatible.displayName == "OpenAI Compatible")
    }

    @Test("LLMProvider has correct default base URLs")
    func llmProviderDefaultURLs() {
        #expect(LLMProvider.openAI.defaultBaseURL?.absoluteString == "https://api.openai.com/v1")
        #expect(LLMProvider.anthropic.defaultBaseURL?.absoluteString == "https://api.anthropic.com/v1")
        #expect(LLMProvider.openRouter.defaultBaseURL?.absoluteString == "https://openrouter.ai/api/v1")
        #expect(LLMProvider.openAICompatible.defaultBaseURL == nil)
    }

    @Test("LLMProvider supports tool calling")
    func llmProviderToolCalling() {
        #expect(LLMProvider.openAI.supportsToolCalling == true)
        #expect(LLMProvider.anthropic.supportsToolCalling == true)
        #expect(LLMProvider.openRouter.supportsToolCalling == true)
        #expect(LLMProvider.openAICompatible.supportsToolCalling == true)
    }

    @Test("LLMProvider suggested models are non-empty")
    func llmProviderSuggestedModels() {
        #expect(LLMProvider.openAI.suggestedModels.isEmpty == false)
        #expect(LLMProvider.anthropic.suggestedModels.isEmpty == false)
        #expect(LLMProvider.openRouter.suggestedModels.isEmpty == false)
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
        #expect(config.baseURL == nil)
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

    // MARK: - AnthropicClient Request Building Tests

    @Test("AnthropicClient baseURL uses config or default")
    func anthropicClientBaseURL() throws {
        let client = AnthropicClient()

        let config = try LLMConfiguration(
            provider: .anthropic,
            apiKeyReference: "test",
            modelName: "claude-sonnet-4-20250514"
        )
        #expect(client.baseURL(for: config).absoluteString == "https://api.anthropic.com/v1")
    }

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

    // MARK: - Prompt Builder Tests

    @Test("CoachingPromptBuilder creates valid request")
    func coachingPromptBuilder() {
        let builder = CoachingPromptBuilder()
        let node = TechniqueTreeNode(
            id: "test",
            techniqueId: "test-technique",
            level: 3,
            name: "Flutter Kick",
            description: "Test description",
            revisit: false,
            metrics: nil,
            prerequisites: [],
            children: [],
            sourceFile: nil
        )

        let request = builder.request(for: node)

        #expect(request.systemRole == "expert_swimming_coach")
        #expect(request.prompt.contains("Flutter Kick"))
        #expect(request.prompt.contains("Test description"))
        #expect(request.temperature == 0.2)
    }

    @Test("CoachingPromptBuilder includes revisit note")
    func coachingPromptBuilderRevisit() {
        let builder = CoachingPromptBuilder()
        let node = TechniqueTreeNode(
            id: "test",
            techniqueId: "test",
            level: 1,
            name: "Body Position",
            description: "Fundamental",
            revisit: true,
            metrics: nil,
            prerequisites: [],
            children: [],
            sourceFile: nil
        )

        let request = builder.request(for: node)
        #expect(request.prompt.contains("fundamental"))
    }

    @Test("GoalSuggestionPromptBuilder creates valid request")
    func goalSuggestionPromptBuilder() {
        let builder = GoalSuggestionPromptBuilder()
        let now = SwimNoteDateFormatting.string(from: Date())
        let note = TrainingNote(
            userId: "test",
            date: "2026-04-28",
            strokeFocus: [.freestyle],
            techniqueFocus: [],
            goals: [],
            notes: "Good session today",
            createdAt: now,
            updatedAt: now
        )
        let recentNotes = [
            TrainingNote(userId: "test", date: "2026-04-27", strokeFocus: [], techniqueFocus: [], goals: [], notes: "Yesterday", createdAt: now, updatedAt: now)
        ]

        let request = builder.request(for: note, recentNotes: recentNotes)

        #expect(request.systemRole == "expert_swimming_coach")
        #expect(request.prompt.contains("Good session today"))
    }
}