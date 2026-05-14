import Foundation

// MARK: - Conversation Message Types

public nonisolated enum ConversationMessage: Sendable, Equatable {
    case system(String)
    case user(String)
    case assistant(String)
    case assistantToolCalls([ToolCall], reasoningContent: String?)  // All tool calls in one message, with reasoning_content for DeepSeek V4
    case toolResult(String, String)  // (toolCallId, result)

    public nonisolated func toOpenAIMessage() -> [String: Any] {
        switch self {
        case .system(let content):
            return ["role": "system", "content": content]
        case .user(let content):
            return ["role": "user", "content": content]
        case .assistant(let content):
            return ["role": "assistant", "content": content]
        case .assistantToolCalls(let toolCalls, let reasoningContent):
            var message: [String: Any] = [
                "role": "assistant",
                "content": NSNull(),
                "tool_calls": toolCalls.map { toolCall in
                    [
                        "id": toolCall.id,
                        "type": toolCall.type,
                        "function": [
                            "name": toolCall.function.name,
                            "arguments": toolCall.function.arguments
                        ]
                    ]
                }
            ]
            // DeepSeek V4 requires reasoning_content round-trip in thinking mode
            if let reasoning = reasoningContent {
                message["reasoning_content"] = reasoning
            }
            return message
        case .toolResult(let toolCallId, let result):
            return [
                "role": "tool",
                "tool_call_id": toolCallId,
                "content": result
            ]
        }
    }
}

// MARK: - Tool Calling Conversation

public final class ToolCallingConversation: Sendable {
    private let configuration: LLMConfiguration
    private let apiKey: String
    private let executor: CombinedToolExecutor

    public init(
        configuration: LLMConfiguration,
        apiKey: String,
        executor: CombinedToolExecutor
    ) {
        self.configuration = configuration
        self.apiKey = apiKey
        self.executor = executor
    }

    private func createClient() -> any LLMClient {
        // P2-2A: native Anthropic was removed; every provider now flows through
        // `OpenAIClient` (OpenRouter speaks the OpenAI chat-completions dialect).
        OpenAIClient()
    }

    public func run(
        systemRole: String,
        userPrompt: String,
        tools: [Tool],
        maxIterations: Int? = nil
    ) async throws -> String {
        // P2-2B: caller can still override; otherwise defer to configuration.
        let resolvedMaxIterations = maxIterations ?? configuration.maxToolIterations
        var messages: [ConversationMessage] = [
            .system(systemRole),
            .user(userPrompt)
        ]

        let client = createClient()
        var consecutiveEmptyResponses = 0

        for iteration in 1...resolvedMaxIterations {
            #if DEBUG
            print("🔧 ToolCalling iteration \(iteration)")
            #endif

            // Build request with full conversation history for OpenAI-compatible APIs
            let request = buildRequestWithHistory(messages: messages, tools: tools)

            do {
                let response = try await client.completeWithTools(request, configuration: configuration, apiKey: apiKey)

                #if DEBUG
                print("🔧 Response content: \(response.content ?? "nil")")
                print("🔧 Has tool calls: \(response.hasToolCalls)")
                if let toolCalls = response.toolCalls {
                    print("🔧 Tool calls: \(toolCalls.map { $0.function.name })")
                }
                #endif

                // If we have content and no tool calls, return it
                if let content = response.content, !content.isEmpty, !response.hasToolCalls {
                    return content
                }

                // DeepSeek V4 thinking mode: If content is empty but reasoning_content has JSON-like content, use it
                if let reasoning = response.reasoningContent, !response.hasToolCalls {
                    // Check if reasoning looks like JSON output (starts with { or [)
                    let trimmed = reasoning.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") || trimmed.hasPrefix("```") {
                        #if DEBUG
                        print("🔧 Using reasoning_content as output (DeepSeek thinking mode)")
                        #endif
                        return reasoning
                    }
                }

                // If we have tool calls, execute them
                if let toolCalls = response.toolCalls, !toolCalls.isEmpty {
                    consecutiveEmptyResponses = 0 // Reset counter

                    // Add ONE assistant message with ALL tool calls (DeepSeek V4 requires this format)
                    messages.append(.assistantToolCalls(toolCalls, reasoningContent: response.reasoningContent))

                    // Execute each tool call and add results
                    for toolCall in toolCalls {
                        #if DEBUG
                        print("🔧 Executing tool: \(toolCall.function.name) with args: \(toolCall.function.arguments)")
                        #endif

                        do {
                            let result = try await executor.execute(toolCall)
                            #if DEBUG
                            print("🔧 Tool result (first 200 chars): \(String(result.prefix(200)))")
                            #endif
                            messages.append(.toolResult(toolCall.id, result))
                        } catch {
                            #if DEBUG
                            print("🔧 Tool execution failed: \(error.localizedDescription)")
                            #endif
                            // Return error as tool result so LLM can handle it
                            messages.append(.toolResult(toolCall.id, "Error: \(error.localizedDescription)"))
                        }
                    }
                } else {
                    // Empty response with no tool calls - might be model thinking
                    consecutiveEmptyResponses += 1
                    #if DEBUG
                    print("🔧 Empty response (consecutive: \(consecutiveEmptyResponses))")
                    #endif

                    // After 2 consecutive empty responses, prompt the model to continue
                    if consecutiveEmptyResponses >= 2 {
                        messages.append(.user("Please continue. Provide the training plan as JSON."))
                        consecutiveEmptyResponses = 0
                    }

                    if iteration == resolvedMaxIterations {
                        // Try to return any content we might have received
                        if let content = response.content, !content.isEmpty {
                            return content
                        }
                        throw LLMServiceError.maxIterationsReached
                    }
                }
            } catch {
                // P2-2B: transport retries (429, 5xx, transient URLErrors) are
                // now handled inside `OpenAIClient.completeWithTools` via
                // `withTransportRetry`. By the time an error reaches here it's
                // either non-retryable or has already exhausted its budget;
                // bubble it up so iterations are not burned on retry sleeps.
                #if DEBUG
                print("🔧 API call failed: \(error.localizedDescription)")
                #endif
                throw error
            }
        }

        throw LLMServiceError.maxIterationsReached
    }

    private func buildRequestWithHistory(messages: [ConversationMessage], tools: [Tool]) -> LLMRequest {
        // Build the request - pass messages directly, conversion happens in LLMClient
        return LLMRequest(
            systemRole: "",  // Empty because system is in messages
            prompt: "",      // Empty because we're using messages array
            temperature: 0.2,
            tools: tools,
            messages: messages
        )
    }
}