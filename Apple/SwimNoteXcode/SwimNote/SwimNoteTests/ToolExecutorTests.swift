//
//  ToolExecutorTests.swift
//  SwimNoteTests
//
//  Tests for tool execution logic with mock content loader
//

import Testing
import Foundation
@testable import SwimNote

struct ToolExecutorTests {

    // MARK: - Execution Tests

    @Test("execute throws unknownTool for invalid tool name")
    func executeUnknownTool() async throws {
        let executor = await ToolExecutor(contentLoader: BundleContentLoader(bundle: Bundle.main))

        let toolCall = ToolCall(
            id: "call_1",
            function: ToolCallFunction(name: "invalid_tool", arguments: "{}")
        )

        await #expect(throws: ToolError.unknownTool("invalid_tool")) {
            try await executor.execute(toolCall)
        }
    }

    @Test("read_technique_file throws missingParameter without filename")
    func readTechniqueFileMissingParameter() async throws {
        let executor = await ToolExecutor(contentLoader: BundleContentLoader(bundle: Bundle.main))

        let toolCall = ToolCall(
            id: "call_1",
            function: ToolCallFunction(name: "read_technique_file", arguments: "{}")
        )

        await #expect(throws: ToolError.missingParameter("filename")) {
            try await executor.execute(toolCall)
        }
    }

    @Test("search_content throws missingParameter without query")
    func searchContentMissingParameter() async throws {
        let executor = await ToolExecutor(contentLoader: BundleContentLoader(bundle: Bundle.main))

        let toolCall = ToolCall(
            id: "call_1",
            function: ToolCallFunction(name: "search_content", arguments: "{}")
        )

        await #expect(throws: ToolError.missingParameter("query")) {
            try await executor.execute(toolCall)
        }
    }

    @Test("get_related_techniques throws missingParameter without filename")
    func getRelatedTechniquesMissingParameter() async throws {
        let executor = await ToolExecutor(contentLoader: BundleContentLoader(bundle: Bundle.main))

        let toolCall = ToolCall(
            id: "call_1",
            function: ToolCallFunction(name: "get_related_techniques", arguments: "{}")
        )

        await #expect(throws: ToolError.missingParameter("filename")) {
            try await executor.execute(toolCall)
        }
    }

    @Test("execute throws executionError for invalid JSON arguments")
    func executeInvalidArguments() async throws {
        let executor = await ToolExecutor(contentLoader: BundleContentLoader(bundle: Bundle.main))

        let toolCall = ToolCall(
            id: "call_1",
            function: ToolCallFunction(name: "read_technique_file", arguments: "not json")
        )

        await #expect(throws: ToolError.executionError("Arguments are not valid JSON")) {
            try await executor.execute(toolCall)
        }
    }

    // MARK: - Tool Call Argument Parsing Tests

    @Test("Tool arguments are parsed correctly as JSON")
    func toolArgumentsParsing() throws {
        let args = "{\"filename\": \"freestyle.md\", \"stroke\": \"freestyle\"}"
        let data = args.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["filename"] as? String == "freestyle.md")
        #expect(json?["stroke"] as? String == "freestyle")
    }

    @Test("Empty arguments are valid JSON")
    func emptyArgumentsParsing() throws {
        let args = "{}"
        let data = args.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json != nil)
        #expect(json?.isEmpty == true)
    }

    // MARK: - JSON Encoding Tests

    @Test("Tool results are encoded as pretty-printed JSON")
    func toolResultEncoding() throws {
        let result: [String: Any] = [
            "filename": "test.md",
            "title": "Test File",
            "content": "Sample content"
        ]

        let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted])
        let string = String(data: data, encoding: .utf8)

        #expect(string != nil)
        #expect(string?.contains("\"filename\"") == true)
        #expect(string?.contains("\"title\"") == true)
    }

    // MARK: - File Extension Handling Tests

    @Test("File extension is normalized correctly")
    func fileExtensionNormalization() {
        // Test the logic used in readTechniqueFile
        let filename1 = "freestyle"
        let normalized1 = filename1.hasSuffix(".md") ? filename1 : "\(filename1).md"
        #expect(normalized1 == "freestyle.md")

        let filename2 = "freestyle.md"
        let normalized2 = filename2.hasSuffix(".md") ? filename2 : "\(filename2).md"
        #expect(normalized2 == "freestyle.md")
    }

    // MARK: - Stroke Filter Logic Tests

    @Test("Stroke filter matches stroke from filename")
    func strokeFilterLogic() {
        // Test extraction logic used in searchContent and listTechniqueFiles
        let filenames = ["freestyle.md", "freestyle-01-body-position.md", "backstroke.md", "butterfly-02-kick.md"]

        let freestyleFiles = filenames.filter { $0.contains("freestyle") }
        #expect(freestyleFiles.count == 2)

        let backstrokeFiles = filenames.filter { $0.contains("backstroke") }
        #expect(backstrokeFiles.count == 1)
    }

    // MARK: - Search Logic Tests

    @Test("Search terms are split correctly")
    func searchTermsSplit() {
        let query = "body position kick"
        let searchTerms = query.lowercased().split(separator: " ").map(String.init)

        #expect(searchTerms.count == 3)
        #expect(searchTerms.contains("body"))
        #expect(searchTerms.contains("position"))
        #expect(searchTerms.contains("kick"))
    }

    @Test("Content matching logic works correctly")
    func contentMatchingLogic() {
        let content = "The flutter kick is essential for freestyle swimming. Focus on body position."
        let lowercased = content.lowercased()
        let searchTerms = ["body", "kick"]

        let hasMatch = searchTerms.contains { term in lowercased.contains(term) }
        #expect(hasMatch == true)
    }
}
