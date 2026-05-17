import Foundation

/// P2-2G: Events emitted by `OpenAIClient.completeWithToolsStream` and
/// `ToolCallingConversation.runStreaming` as the model streams its reply.
///
/// Plan generation is the longest perceived wait in the app — until P2-2G
/// the user only saw a spinner. With streaming, callers (e.g. PlanningView)
/// can render `.contentDelta` chunks into a "drafting…" panel as the model
/// thinks aloud, then commit the final result on `.finished`.
///
/// The event sequence for a typical streaming response is roughly:
///
///   .contentDelta("The "), .contentDelta("workout "), .contentDelta("is…")
///   .toolCallDelta(...)         // optional, may interleave
///   .usage(...)                 // optional, only if the API reports it
///   .finished(LLMResponse)      // always last
///
/// Errors from the underlying transport are *thrown* by the
/// `AsyncThrowingStream`, not surfaced as events — callers handle them via
/// the standard `for try await` error path.
public enum LLMStreamEvent: Sendable {
    /// Incremental assistant content. Concatenate these to build the full
    /// reply string. Empty strings are valid (some providers emit them as
    /// keep-alives) and should be tolerated.
    case contentDelta(String)

    /// Incremental tool-call delta. OpenAI streams `tool_calls` piecewise:
    /// the first chunk usually contains `id` and `function.name`; subsequent
    /// chunks add to `function.arguments`. `index` lets callers stitch
    /// deltas for the same tool call together when the model emits multiple
    /// in parallel.
    case toolCallDelta(index: Int, id: String?, name: String?, argumentsDelta: String?)

    /// Token usage as reported by the API (when `stream_options.include_usage`
    /// is on). Optional — many providers omit this for streaming responses.
    case usage(promptTokens: Int, completionTokens: Int, totalTokens: Int)

    /// Terminal event with the fully assembled response. Always the last
    /// event in a successful stream. Callers should rely on this rather than
    /// re-assembling deltas themselves so semantics stay in sync with the
    /// non-streaming `completeWithTools` path.
    case finished(LLMResponse)
}

extension LLMStreamEvent: Equatable {
    public nonisolated static func == (lhs: LLMStreamEvent, rhs: LLMStreamEvent) -> Bool {
        switch (lhs, rhs) {
        case let (.contentDelta(a), .contentDelta(b)):
            return a == b
        case let (.toolCallDelta(i1, id1, n1, a1), .toolCallDelta(i2, id2, n2, a2)):
            return i1 == i2 && id1 == id2 && n1 == n2 && a1 == a2
        case let (.usage(p1, c1, t1), .usage(p2, c2, t2)):
            return p1 == p2 && c1 == c2 && t1 == t2
        case let (.finished(l), .finished(r)):
            return l == r
        default:
            return false
        }
    }
}

extension LLMResponse: Equatable {
    public nonisolated static func == (lhs: LLMResponse, rhs: LLMResponse) -> Bool {
        lhs.content == rhs.content &&
        lhs.reasoningContent == rhs.reasoningContent &&
        (lhs.toolCalls?.map(\.id) ?? []) == (rhs.toolCalls?.map(\.id) ?? [])
    }
}

// MARK: - SSE line parser (extracted for unit testing)

/// Parser for OpenAI's chat-completions Server-Sent Events stream.
///
/// SSE wire format (one event per blank-line-separated block):
///
///   data: {"choices":[{"delta":{"content":"Hello"}}]}
///
///   data: {"choices":[{"delta":{"content":" world"}}]}
///
///   data: [DONE]
///
/// We treat each `data:` payload independently (none of OpenAI's events span
/// multiple `data:` lines in practice). `[DONE]` is the sentinel that closes
/// the stream — when we see it, we emit `.finished` with whatever we've
/// accumulated.
public enum OpenAISSEParser {
    /// Translate a single SSE `data:` payload into zero or more
    /// `LLMStreamEvent` values plus a `done` flag indicating the stream
    /// terminated. The accumulator (`content`, `toolCalls`, `reasoning`) is
    /// passed in by reference so the caller can build the final `LLMResponse`
    /// for the terminal `.finished` event.
    ///
    /// Returns `nil` events list if the payload is unparseable JSON — we log
    /// and skip rather than crash, since OpenAI occasionally emits comment
    /// lines or warnings.
    public static func parseDataPayload(
        _ payload: String,
        accumulator: inout StreamAccumulator
    ) -> ParsedLine {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "[DONE]" {
            return ParsedLine(events: [], done: true)
        }

        guard let data = trimmed.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ParsedLine(events: [], done: false)
        }

        var events: [LLMStreamEvent] = []

        // Usage block (optional; appears as a separate event when
        // stream_options.include_usage is set).
        if let usage = json["usage"] as? [String: Any],
           let prompt = usage["prompt_tokens"] as? Int,
           let completion = usage["completion_tokens"] as? Int,
           let total = usage["total_tokens"] as? Int {
            events.append(.usage(promptTokens: prompt, completionTokens: completion, totalTokens: total))
        }

        guard let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first else {
            return ParsedLine(events: events, done: false)
        }

        if let delta = firstChoice["delta"] as? [String: Any] {
            if let contentDelta = delta["content"] as? String, !contentDelta.isEmpty {
                accumulator.appendContent(contentDelta)
                events.append(.contentDelta(contentDelta))
            }
            if let reasoningDelta = delta["reasoning_content"] as? String, !reasoningDelta.isEmpty {
                accumulator.appendReasoning(reasoningDelta)
                // Reasoning is internal model state; surface as content delta
                // only if a caller specifically wants it. For now we
                // accumulate silently and expose via the final LLMResponse.
            }
            if let toolCallDeltas = delta["tool_calls"] as? [[String: Any]] {
                for toolCallJson in toolCallDeltas {
                    let index = (toolCallJson["index"] as? Int) ?? 0
                    let id = toolCallJson["id"] as? String
                    let function = toolCallJson["function"] as? [String: Any]
                    let name = function?["name"] as? String
                    let argumentsDelta = function?["arguments"] as? String
                    accumulator.appendToolCallDelta(
                        index: index,
                        id: id,
                        name: name,
                        argumentsDelta: argumentsDelta
                    )
                    events.append(.toolCallDelta(
                        index: index,
                        id: id,
                        name: name,
                        argumentsDelta: argumentsDelta
                    ))
                }
            }
        }

        // OpenAI sometimes signals end-of-stream via finish_reason on the
        // last delta rather than (or in addition to) [DONE]. Treat both as
        // legitimate stream terminators so we don't hang.
        let finishReason = firstChoice["finish_reason"] as? String
        if finishReason != nil && !finishReason!.isEmpty {
            // Don't mark done here — wait for [DONE] sentinel so `.usage`
            // events delivered after finish_reason aren't dropped.
        }

        return ParsedLine(events: events, done: false)
    }

    /// Assembled result of parsing a single SSE `data:` payload.
    public struct ParsedLine: Sendable, Equatable {
        public let events: [LLMStreamEvent]
        public let done: Bool

        public init(events: [LLMStreamEvent], done: Bool) {
            self.events = events
            self.done = done
        }
    }
}

/// Mutable accumulator the SSE parser writes into so the eventual
/// `.finished(LLMResponse)` event can carry the fully reassembled message.
public struct StreamAccumulator: Sendable {
    public private(set) var content: String = ""
    public private(set) var reasoning: String = ""
    public private(set) var toolCalls: [Int: PartialToolCall] = [:]

    public init() {}

    public mutating func appendContent(_ delta: String) {
        content.append(delta)
    }

    public mutating func appendReasoning(_ delta: String) {
        reasoning.append(delta)
    }

    public mutating func appendToolCallDelta(
        index: Int,
        id: String?,
        name: String?,
        argumentsDelta: String?
    ) {
        var partial = toolCalls[index] ?? PartialToolCall()
        if let id = id { partial.id = id }
        if let name = name { partial.name = name }
        if let argumentsDelta = argumentsDelta {
            partial.arguments.append(argumentsDelta)
        }
        toolCalls[index] = partial
    }

    /// Materialize the accumulator into a final `LLMResponse`. Tool calls
    /// without an `id` and `name` are dropped — they're partial deltas that
    /// the model never finished emitting (rare, but possible on early stream
    /// termination).
    public func makeResponse() -> LLMResponse {
        let assembled: [ToolCall] = toolCalls
            .sorted { $0.key < $1.key }
            .compactMap { _, partial in
                guard let id = partial.id, let name = partial.name else { return nil }
                return ToolCall(
                    id: id,
                    type: "function",
                    function: ToolCallFunction(name: name, arguments: partial.arguments)
                )
            }

        return LLMResponse(
            content: content.isEmpty ? nil : content,
            toolCalls: assembled.isEmpty ? nil : assembled,
            reasoningContent: reasoning.isEmpty ? nil : reasoning
        )
    }

    public struct PartialToolCall: Sendable, Equatable {
        public var id: String?
        public var name: String?
        public var arguments: String = ""

        public init() {}
    }
}
