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
        maxIterations: Int? = nil,
        maxTokens: Int? = nil
    ) async throws -> String {
        // P2-2B: caller can still override; otherwise defer to configuration.
        let resolvedMaxIterations = maxIterations ?? configuration.maxToolIterations
        // P2-2C: per-call max_tokens cap; nil falls back to OpenAIClient default.
        let resolvedMaxTokens = maxTokens
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
            let request = buildRequestWithHistory(
                messages: messages,
                tools: tools,
                maxTokens: resolvedMaxTokens
            )

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

                    // P2-2F: execute every tool call in this round concurrently. Tool
                    // results are correlated by `tool_call_id`, so server-side ordering
                    // is preserved regardless of completion order — but we still
                    // re-stitch results into the original `toolCalls` order before
                    // appending so the conversation log stays deterministic.
                    let executor = self.executor
                    let results = await Self.executeToolCallsInParallel(toolCalls) { toolCall in
                        #if DEBUG
                        print("🔧 Executing tool: \(toolCall.function.name) with args: \(toolCall.function.arguments)")
                        #endif
                        do {
                            let result = try await executor.execute(toolCall)
                            #if DEBUG
                            print("🔧 Tool result (first 200 chars): \(String(result.prefix(200)))")
                            #endif
                            return result
                        } catch {
                            #if DEBUG
                            print("🔧 Tool execution failed: \(error.localizedDescription)")
                            #endif
                            // Surface the error to the LLM as a tool result so it can
                            // recover, matching the previous sequential behaviour.
                            return "Error: \(error.localizedDescription)"
                        }
                    }

                    for (toolCall, result) in results {
                        messages.append(.toolResult(toolCall.id, result))
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

    private func buildRequestWithHistory(
        messages: [ConversationMessage],
        tools: [Tool],
        maxTokens: Int? = nil
    ) -> LLMRequest {
        // Build the request - pass messages directly, conversion happens in LLMClient
        return LLMRequest(
            systemRole: "",  // Empty because system is in messages
            prompt: "",      // Empty because we're using messages array
            temperature: 0.2,
            tools: tools,
            messages: messages,
            maxTokens: maxTokens
        )
    }

    /// P2-2F helper: fans `toolCalls` out across a `withTaskGroup`, awaits all
    /// results, and re-orders them to match the input order so callers stay
    /// deterministic. Errors are translated to strings by `perform`, so the
    /// task group itself never throws and individual failures don't cancel
    /// sibling tool executions in the same round.
    ///
    /// Exposed at internal visibility (not private) so tests can drive the
    /// parallelism contract directly without wiring a fake `LLMClient`.
    static func executeToolCallsInParallel(
        _ toolCalls: [ToolCall],
        perform: @Sendable @escaping (ToolCall) async -> String
    ) async -> [(ToolCall, String)] {
        await withTaskGroup(of: (Int, String).self) { group in
            for (index, toolCall) in toolCalls.enumerated() {
                group.addTask {
                    let result = await perform(toolCall)
                    return (index, result)
                }
            }
            var collected: [(Int, String)] = []
            for await pair in group {
                collected.append(pair)
            }
            return collected.sorted { $0.0 < $1.0 }.map { (toolCalls[$0.0], $0.1) }
        }
    }

    // MARK: - P2-2G Streaming variant

    /// P2-2G: streaming analog of `run`. Yields `LLMStreamEvent`s from the
    /// underlying SSE stream so UI can render incremental content while the
    /// model thinks. Tool execution still runs in parallel via P2-2F's
    /// helper between rounds.
    ///
    /// The final assistant content (after all tool rounds resolve) is
    /// emitted as `.contentDelta` if the model chose to send text on the
    /// last round, then closed with a `.finished(LLMResponse)`.
    ///
    /// Errors thrown by the LLM client or tool executor surface through the
    /// stream's error path; callers should `for try await event in stream`.
    public func runStreaming(
        systemRole: String,
        userPrompt: String,
        tools: [Tool],
        maxIterations: Int? = nil,
        maxTokens: Int? = nil
    ) -> AsyncThrowingStream<LLMStreamEvent, Error> {
        let resolvedMaxIterations = maxIterations ?? configuration.maxToolIterations
        let resolvedMaxTokens = maxTokens
        let configuration = self.configuration
        let apiKey = self.apiKey
        let executor = self.executor

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var messages: [ConversationMessage] = [
                        .system(systemRole),
                        .user(userPrompt)
                    ]
                    let openAIClient = OpenAIClient()

                    for iteration in 1...resolvedMaxIterations {
                        try Task.checkCancellation()

                        let request = LLMRequest(
                            systemRole: "",
                            prompt: "",
                            temperature: 0.2,
                            tools: tools,
                            messages: messages,
                            maxTokens: resolvedMaxTokens
                        )

                        // Stream this round; collect deltas + the final
                        // assembled response (carrying any tool calls) from
                        // the terminal `.finished` event.
                        var roundResponse: LLMResponse?
                        let stream = openAIClient.completeWithToolsStream(
                            request,
                            configuration: configuration,
                            apiKey: apiKey
                        )
                        for try await event in stream {
                            try Task.checkCancellation()
                            // Forward content + usage events upstream so the
                            // UI can render. Tool-call deltas and finished
                            // are consumed here for control flow but also
                            // forwarded so observers can show "calling
                            // tool…" hints.
                            continuation.yield(event)
                            if case .finished(let response) = event {
                                roundResponse = response
                            }
                        }

                        guard let response = roundResponse else {
                            throw LLMServiceError.invalidResponse
                        }

                        // No tool calls — terminal turn, we're done.
                        if !response.hasToolCalls {
                            continuation.finish()
                            return
                        }

                        // Tool calls: append assistant turn, fan-out execute,
                        // append results, loop.
                        guard let toolCalls = response.toolCalls else {
                            continuation.finish()
                            return
                        }
                        messages.append(.assistantToolCalls(toolCalls, reasoningContent: response.reasoningContent))

                        let results = await Self.executeToolCallsInParallel(toolCalls) { toolCall in
                            do {
                                return try await executor.execute(toolCall)
                            } catch {
                                return "Error: \(error.localizedDescription)"
                            }
                        }
                        for (toolCall, result) in results {
                            messages.append(.toolResult(toolCall.id, result))
                        }

                        if iteration == resolvedMaxIterations {
                            throw LLMServiceError.maxIterationsReached
                        }
                    }

                    throw LLMServiceError.maxIterationsReached
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}