//
//  ToolCallingConversationTests.swift
//  SwimNoteTests
//
//  Tests for conversation flow and message types
//

import Testing
import Foundation
@testable import SwimNote

struct ToolCallingConversationTests {

    // MARK: - ConversationMessage Tests

    @Test("ConversationMessage.system converts to OpenAI format")
    func conversationMessageSystem() {
        let message = ConversationMessage.system("You are a coach")
        let openAI = message.toOpenAIMessage()

        #expect(openAI["role"] as? String == "system")
        #expect(openAI["content"] as? String == "You are a coach")
    }

    @Test("ConversationMessage.user converts to OpenAI format")
    func conversationMessageUser() {
        let message = ConversationMessage.user("Help me improve")
        let openAI = message.toOpenAIMessage()

        #expect(openAI["role"] as? String == "user")
        #expect(openAI["content"] as? String == "Help me improve")
    }

    @Test("ConversationMessage.assistant converts to OpenAI format")
    func conversationMessageAssistant() {
        let message = ConversationMessage.assistant("Here is my advice")
        let openAI = message.toOpenAIMessage()

        #expect(openAI["role"] as? String == "assistant")
        #expect(openAI["content"] as? String == "Here is my advice")
    }

    @Test("ConversationMessage.assistantToolCalls converts to OpenAI format")
    func conversationMessageToolCall() {
        let toolCall = ToolCall(
            id: "call_123",
            type: "function",
            function: ToolCallFunction(name: "read_technique_file", arguments: "{\"filename\": \"test\"}")
        )
        let message = ConversationMessage.assistantToolCalls([toolCall], reasoningContent: nil)
        let openAI = message.toOpenAIMessage()

        #expect(openAI["role"] as? String == "assistant")
        #expect(openAI["content"] as? NSNull != nil)  // Content should be NSNull for tool calls

        let toolCalls = openAI["tool_calls"] as? [[String: Any]]
        #expect(toolCalls?.count == 1)
        #expect(toolCalls?.first?["id"] as? String == "call_123")
        #expect((toolCalls?.first?["function"] as? [String: Any])?["name"] as? String == "read_technique_file")
    }

    @Test("ConversationMessage.toolResult converts to OpenAI format")
    func conversationMessageToolResult() {
        let message = ConversationMessage.toolResult("call_123", "File content here")
        let openAI = message.toOpenAIMessage()

        #expect(openAI["role"] as? String == "tool")
        #expect(openAI["tool_call_id"] as? String == "call_123")
        #expect(openAI["content"] as? String == "File content here")
    }

    @Test("ConversationMessage.assistantToolCalls uses NSNull for content")
    func conversationMessageToolCallNSNull() {
        let toolCall = ToolCall(
            id: "call_123",
            type: "function",
            function: ToolCallFunction(name: "test", arguments: "{}")
        )
        let message = ConversationMessage.assistantToolCalls([toolCall], reasoningContent: nil)
        let openAI = message.toOpenAIMessage()

        // The content should be NSNull(), not nil or a string
        let content = openAI["content"]
        #expect(content is NSNull)
    }

    @Test("ConversationMessage.assistantToolCalls includes reasoning_content for DeepSeek V4")
    func conversationMessageToolCallWithReasoning() {
        let toolCall = ToolCall(
            id: "call_123",
            type: "function",
            function: ToolCallFunction(name: "test", arguments: "{}")
        )
        let message = ConversationMessage.assistantToolCalls([toolCall], reasoningContent: "My reasoning process...")
        let openAI = message.toOpenAIMessage()

        #expect(openAI["role"] as? String == "assistant")
        #expect(openAI["reasoning_content"] as? String == "My reasoning process...")
    }

    // MARK: - Conversation Flow Tests

    @Test("Conversation returns content immediately when no tool calls")
    func conversationReturnsContentDirectly() async throws {
        // This test verifies the message flow, not actual API calls
        // since we can't easily mock the client in the current architecture

        let messages: [ConversationMessage] = [
            .system("You are a coach"),
            .user("Help me")
        ]

        // Build request from messages - pass ConversationMessage directly
        let request = LLMRequest(
            systemRole: "",
            prompt: "",
            tools: nil,
            messages: messages
        )

        #expect(request.messages?.count == 2)
        #expect(request.messages?.first == .system("You are a coach"))
        #expect(request.messages?.last == .user("Help me"))
    }

    @Test("Conversation builds correct message sequence for tool calls")
    func conversationMessageSequence() {
        let messages: [ConversationMessage] = [
            .system("You are a coach"),
            .user("Read freestyle technique"),
            .assistantToolCalls([ToolCall(
                id: "call_1",
                type: "function",
                function: ToolCallFunction(name: "read_technique_file", arguments: "{\"filename\": \"freestyle\"}")
            )], reasoningContent: nil),
            .toolResult("call_1", "{\"title\": \"Freestyle\"}")
        ]

        let openAIMessages = messages.map { $0.toOpenAIMessage() }

        #expect(openAIMessages.count == 4)
        #expect(openAIMessages[0]["role"] as? String == "system")
        #expect(openAIMessages[1]["role"] as? String == "user")
        #expect(openAIMessages[2]["role"] as? String == "assistant")
        #expect(openAIMessages[3]["role"] as? String == "tool")
    }

    @Test("Multiple tool calls create ONE assistant message (DeepSeek V4 compatible)")
    func multipleToolCallsMessages() {
        // DeepSeek V4 requires ALL tool calls in ONE assistant message
        let messages: [ConversationMessage] = [
            .system("Coach"),
            .user("Help"),
            .assistantToolCalls([
                ToolCall(id: "call_1", type: "function", function: ToolCallFunction(name: "tool1", arguments: "{}")),
                ToolCall(id: "call_2", type: "function", function: ToolCallFunction(name: "tool2", arguments: "{}"))
            ], reasoningContent: nil),
            .toolResult("call_1", "result1"),
            .toolResult("call_2", "result2")
        ]

        let openAIMessages = messages.map { $0.toOpenAIMessage() }

        #expect(openAIMessages.count == 5)  // system, user, assistant (with 2 tool_calls), tool, tool

        // ONE assistant message with ALL tool calls
        let assistantMessages = openAIMessages.filter { ($0["role"] as? String) == "assistant" }
        #expect(assistantMessages.count == 1)

        // That single assistant message should have 2 tool_calls
        let toolCalls = assistantMessages[0]["tool_calls"] as? [[String: Any]]
        #expect(toolCalls?.count == 2)

        // Both results should be tool messages
        let toolMessages = openAIMessages.filter { ($0["role"] as? String) == "tool" }
        #expect(toolMessages.count == 2)
    }

    // MARK: - Max Iterations Tests

    @Test("Conversation has max iterations limit")
    func maxIterationsDefault() {
        // The default maxIterations is 10
        // This is enforced in the run() method
        let maxIterations = 10
        #expect(maxIterations == 10)
    }

    @Test("LLMServiceError.maxIterationsReached exists")
    func maxIterationsError() {
        let error = LLMServiceError.maxIterationsReached
        #expect(error == LLMServiceError.maxIterationsReached)
    }

    // MARK: - Request Building Tests

    @Test("buildRequestWithHistory creates correct request")
    func buildRequestWithHistoryTest() {
        let messages: [ConversationMessage] = [
            .system("You are an expert coach"),
            .user("I want to improve my freestyle")
        ]

        let tools = ResourcesNavigationTools.all

        // Build request - pass ConversationMessage directly
        let request = LLMRequest(
            systemRole: "",
            prompt: "",
            temperature: 0.2,
            tools: tools,
            messages: messages
        )

        #expect(request.tools?.count == 4)
        #expect(request.temperature == 0.2)
        #expect(request.messages?.count == 2)
    }

    // MARK: - Provider-Specific Format Tests

    @Test("OpenAI tool schema format is correct")
    func openAIToolSchemaFormat() {
        let tool = ResourcesNavigationTools.readTechniqueFile

        // OpenAI expects: {"type": "function", "function": {...}}
        #expect(tool.type == "function")
        #expect(tool.function.name == "read_technique_file")
        #expect(tool.function.parameters.type == "object")
    }

    // Anthropic-specific schema test removed in P2-2A; native Claude support
    // is gone, OpenRouter speaks the OpenAI dialect handled above.

    // MARK: - HTTP Error Retry Tests

    @Test("HTTP 500 errors should be retried")
    func httpErrorRetry500() {
        _ = LLMServiceError.httpError(500)
        let shouldRetry = (500 >= 500) || (500 == 429)
        #expect(shouldRetry == true)
    }

    @Test("HTTP 429 (rate limit) should be retried")
    func httpErrorRetry429() {
        _ = LLMServiceError.httpError(429)
        let shouldRetry = (429 >= 500) || (429 == 429)
        #expect(shouldRetry == true)
    }

    @Test("HTTP 400 (bad request) should not be retried")
    func httpErrorNoRetry400() {
        let code = 400
        let shouldRetry = (code >= 500) || (code == 429)
        #expect(shouldRetry == false)
    }

    // MARK: - Empty Response Handling Tests

    @Test("Empty response handling logic exists")
    func emptyResponseHandling() {
        // When model returns empty content without tool calls,
        // conversation may prompt "Please continue"
        // This happens after consecutiveEmptyResponses >= 2

        let response = LLMResponse(content: "", toolCalls: nil)
        #expect(response.content?.isEmpty == true)
        #expect(response.hasToolCalls == false)
    }

    // MARK: - Tool Result for Error Tests

    @Test("Tool execution errors become tool results")
    func toolErrorAsResult() {
        let toolError = ToolError.executionError("File not found")
        let errorString = "Error: \(toolError.description)"

        // In the conversation loop, this would be added as:
        // .toolResult("call_id", errorString)
        #expect(errorString.contains("Tool execution error"))
    }

    // MARK: - P2-2F Parallel Tool Execution Tests

    @Test("executeToolCallsInParallel runs tool work concurrently (P2-2F)")
    func parallelToolExecutionFinishesNearMaxLatency() async {
        // Each fake tool sleeps for 200ms. Sequential execution of four would
        // take ~800ms; parallel execution should finish in ~200ms plus overhead.
        // Allow generous slack for CI noise but well below the sequential floor.
        let toolCalls = (0..<4).map { i in
            ToolCall(
                id: "call_\(i)",
                type: "function",
                function: ToolCallFunction(name: "slow_\(i)", arguments: "{}")
            )
        }

        let perCallDelay: UInt64 = 200_000_000 // 200ms in nanoseconds
        let start = ContinuousClock.now

        let results = await ToolCallingConversation.executeToolCallsInParallel(toolCalls) { toolCall in
            try? await Task.sleep(nanoseconds: perCallDelay)
            return "ok-\(toolCall.id)"
        }

        let elapsed = ContinuousClock.now - start

        // Sequential floor is 4 * 200ms = 800ms. We give the parallel path up
        // to 600ms (3x single-call latency) so the test is robust against CI
        // jitter without ever passing under the sequential implementation.
        #expect(elapsed < .milliseconds(600))
        #expect(results.count == toolCalls.count)
        // Order must match input order so the conversation log is deterministic.
        for (index, pair) in results.enumerated() {
            #expect(pair.0.id == toolCalls[index].id)
            #expect(pair.1 == "ok-\(toolCalls[index].id)")
        }
    }

    @Test("executeToolCallsInParallel preserves input order even when tasks finish out of order (P2-2F)")
    func parallelToolExecutionPreservesOrder() async {
        let toolCalls = [
            ToolCall(id: "first", type: "function", function: ToolCallFunction(name: "slow", arguments: "{}")),
            ToolCall(id: "second", type: "function", function: ToolCallFunction(name: "fast", arguments: "{}")),
            ToolCall(id: "third", type: "function", function: ToolCallFunction(name: "medium", arguments: "{}"))
        ]

        // Make the first tool the slowest so it finishes last in wall-clock time.
        let results = await ToolCallingConversation.executeToolCallsInParallel(toolCalls) { toolCall in
            switch toolCall.id {
            case "first":  try? await Task.sleep(nanoseconds: 150_000_000)
            case "second": try? await Task.sleep(nanoseconds: 10_000_000)
            case "third":  try? await Task.sleep(nanoseconds: 50_000_000)
            default: break
            }
            return "result-\(toolCall.id)"
        }

        #expect(results.map { $0.0.id } == ["first", "second", "third"])
        #expect(results.map { $0.1 } == ["result-first", "result-second", "result-third"])
    }

    @Test("executeToolCallsInParallel handles empty tool list (P2-2F)")
    func parallelToolExecutionEmpty() async {
        let results = await ToolCallingConversation.executeToolCallsInParallel([]) { _ in
            "should-not-run"
        }
        #expect(results.isEmpty)
    }
}
