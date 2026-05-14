//
//  StreamingTests.swift
//  SwimNoteTests
//
//  P2-2G: SSE parsing + LLMStreamEvent assembly tests. Drives the
//  `OpenAISSEParser` and `StreamAccumulator` directly with hand-rolled
//  fixtures so we can verify the contract without standing up a real
//  HTTP server.
//

import Testing
import Foundation
@testable import SwimNote

struct StreamingTests {

    // MARK: - Single-delta payloads

    @Test("Parses a content delta into .contentDelta event (P2-2G)")
    func contentDelta() {
        var acc = StreamAccumulator()
        let payload = #"{"choices":[{"delta":{"content":"Hello"}}]}"#

        let parsed = OpenAISSEParser.parseDataPayload(payload, accumulator: &acc)

        #expect(parsed.events == [.contentDelta("Hello")])
        #expect(parsed.done == false)
        #expect(acc.content == "Hello")
    }

    @Test("Empty content deltas are skipped (P2-2G)")
    func emptyContentDeltaSkipped() {
        var acc = StreamAccumulator()
        let payload = #"{"choices":[{"delta":{"content":""}}]}"#

        let parsed = OpenAISSEParser.parseDataPayload(payload, accumulator: &acc)

        // Empty deltas are providers' way of keeping the connection alive;
        // surfacing them as events would force every consumer to filter.
        #expect(parsed.events.isEmpty)
        #expect(acc.content.isEmpty)
    }

    @Test("[DONE] sentinel marks parsed line as done (P2-2G)")
    func doneSentinel() {
        var acc = StreamAccumulator()

        let parsed = OpenAISSEParser.parseDataPayload("[DONE]", accumulator: &acc)

        #expect(parsed.events.isEmpty)
        #expect(parsed.done == true)
    }

    @Test("Whitespace around [DONE] is tolerated (P2-2G)")
    func doneSentinelWhitespace() {
        var acc = StreamAccumulator()

        let parsed = OpenAISSEParser.parseDataPayload("  [DONE]  ", accumulator: &acc)

        #expect(parsed.done == true)
    }

    @Test("Malformed JSON payload yields no events and no crash (P2-2G)")
    func malformedJSONIsIgnored() {
        var acc = StreamAccumulator()
        let payload = "not-json-at-all"

        let parsed = OpenAISSEParser.parseDataPayload(payload, accumulator: &acc)

        #expect(parsed.events.isEmpty)
        #expect(parsed.done == false)
    }

    @Test("Usage payload yields .usage event (P2-2G)")
    func usagePayload() {
        var acc = StreamAccumulator()
        let payload = #"""
        {"choices":[],"usage":{"prompt_tokens":42,"completion_tokens":17,"total_tokens":59}}
        """#

        let parsed = OpenAISSEParser.parseDataPayload(payload, accumulator: &acc)

        #expect(parsed.events == [.usage(promptTokens: 42, completionTokens: 17, totalTokens: 59)])
    }

    // MARK: - Tool call deltas

    @Test("Tool call delta with full id+name+args yields .toolCallDelta (P2-2G)")
    func toolCallDeltaFull() {
        var acc = StreamAccumulator()
        let payload = #"""
        {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_1","function":{"name":"read_file","arguments":"{\"path\":\"a\"}"}}]}}]}
        """#

        let parsed = OpenAISSEParser.parseDataPayload(payload, accumulator: &acc)

        #expect(parsed.events.count == 1)
        if case .toolCallDelta(let index, let id, let name, let argsDelta) = parsed.events[0] {
            #expect(index == 0)
            #expect(id == "call_1")
            #expect(name == "read_file")
            #expect(argsDelta == #"{"path":"a"}"#)
        } else {
            Issue.record("Expected .toolCallDelta")
        }
        #expect(acc.toolCalls[0]?.id == "call_1")
        #expect(acc.toolCalls[0]?.name == "read_file")
        #expect(acc.toolCalls[0]?.arguments == #"{"path":"a"}"#)
    }

    @Test("Tool call deltas accumulate arguments across chunks (P2-2G)")
    func toolCallDeltaAccumulates() {
        var acc = StreamAccumulator()

        // First chunk: id + name, no args
        let p1 = #"{"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_1","function":{"name":"slow"}}]}}]}"#
        _ = OpenAISSEParser.parseDataPayload(p1, accumulator: &acc)

        // Subsequent chunks: argument fragments
        let p2 = #"{"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"{\"x\":"}}]}}]}"#
        _ = OpenAISSEParser.parseDataPayload(p2, accumulator: &acc)
        let p3 = #"{"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"1}"}}]}}]}"#
        _ = OpenAISSEParser.parseDataPayload(p3, accumulator: &acc)

        #expect(acc.toolCalls[0]?.id == "call_1")
        #expect(acc.toolCalls[0]?.name == "slow")
        #expect(acc.toolCalls[0]?.arguments == #"{"x":1}"#)
    }

    @Test("Multiple parallel tool calls keyed by index (P2-2G)")
    func toolCallDeltaMultipleIndexes() {
        var acc = StreamAccumulator()

        let p1 = #"{"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_a","function":{"name":"a","arguments":"{}"}}]}}]}"#
        let p2 = #"{"choices":[{"delta":{"tool_calls":[{"index":1,"id":"call_b","function":{"name":"b","arguments":"{}"}}]}}]}"#
        _ = OpenAISSEParser.parseDataPayload(p1, accumulator: &acc)
        _ = OpenAISSEParser.parseDataPayload(p2, accumulator: &acc)

        #expect(acc.toolCalls.count == 2)
        #expect(acc.toolCalls[0]?.id == "call_a")
        #expect(acc.toolCalls[1]?.id == "call_b")
    }

    // MARK: - Full hand-rolled SSE replay

    @Test("Replay of a hand-rolled SSE conversation produces expected event sequence (P2-2G)")
    func handRolledSSEReplay() {
        var acc = StreamAccumulator()
        var allEvents: [LLMStreamEvent] = []
        var sawDone = false

        // Fixture: a model that streams "The pool is open." then [DONE].
        let payloads: [String] = [
            #"{"choices":[{"delta":{"role":"assistant"}}]}"#,
            #"{"choices":[{"delta":{"content":"The "}}]}"#,
            #"{"choices":[{"delta":{"content":"pool "}}]}"#,
            #"{"choices":[{"delta":{"content":"is "}}]}"#,
            #"{"choices":[{"delta":{"content":"open."},"finish_reason":"stop"}]}"#,
            #"{"choices":[],"usage":{"prompt_tokens":10,"completion_tokens":4,"total_tokens":14}}"#,
            "[DONE]"
        ]

        for payload in payloads {
            let parsed = OpenAISSEParser.parseDataPayload(payload, accumulator: &acc)
            allEvents.append(contentsOf: parsed.events)
            if parsed.done {
                sawDone = true
                break
            }
        }

        #expect(sawDone == true)
        #expect(acc.content == "The pool is open.")
        // Content deltas + one usage event (the role-only delta produces no event).
        let contentDeltas = allEvents.compactMap { event -> String? in
            if case .contentDelta(let s) = event { return s } else { return nil }
        }
        #expect(contentDeltas == ["The ", "pool ", "is ", "open."])
        let usageEvents = allEvents.filter { if case .usage = $0 { return true } else { return false } }
        #expect(usageEvents.count == 1)

        let assembled = acc.makeResponse()
        #expect(assembled.content == "The pool is open.")
        #expect(assembled.toolCalls == nil)
    }

    // MARK: - Accumulator -> LLMResponse contract

    @Test("Accumulator drops partial tool calls missing id or name (P2-2G)")
    func accumulatorDropsPartialToolCalls() {
        var acc = StreamAccumulator()

        // index 0: complete (id + name)
        acc.appendToolCallDelta(index: 0, id: "call_complete", name: "tool_a", argumentsDelta: "{}")
        // index 1: never received an id — must be dropped
        acc.appendToolCallDelta(index: 1, id: nil, name: "tool_b", argumentsDelta: "{}")
        // index 2: never received a name — must be dropped
        acc.appendToolCallDelta(index: 2, id: "call_partial", name: nil, argumentsDelta: "{}")

        let response = acc.makeResponse()

        #expect(response.toolCalls?.count == 1)
        #expect(response.toolCalls?.first?.id == "call_complete")
    }

    @Test("Accumulator with no content and no tool calls yields nil-content response (P2-2G)")
    func accumulatorEmptyResponse() {
        let acc = StreamAccumulator()

        let response = acc.makeResponse()

        #expect(response.content == nil)
        #expect(response.toolCalls == nil)
        #expect(response.reasoningContent == nil)
    }

    @Test("Reasoning content accumulates silently and surfaces via final response (P2-2G)")
    func accumulatorReasoning() {
        var acc = StreamAccumulator()

        let p1 = #"{"choices":[{"delta":{"reasoning_content":"Step 1: "}}]}"#
        let p2 = #"{"choices":[{"delta":{"reasoning_content":"think."}}]}"#
        let r1 = OpenAISSEParser.parseDataPayload(p1, accumulator: &acc)
        let r2 = OpenAISSEParser.parseDataPayload(p2, accumulator: &acc)

        // Reasoning is stored but not surfaced as events (yet).
        #expect(r1.events.isEmpty)
        #expect(r2.events.isEmpty)

        let response = acc.makeResponse()
        #expect(response.reasoningContent == "Step 1: think.")
    }
}
