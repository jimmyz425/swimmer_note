//
//  ToolDefinitionsTests.swift
//  SwimNoteTests
//
//  Tests for tool definitions and JSON schema validation
//

import Testing
import Foundation
@testable import SwimNote

struct ToolDefinitionsTests {

    // MARK: - Tool Schema Tests

    @Test("Tool type defaults to function")
    func toolTypeDefaultsToFunction() {
        let tool = ResourcesNavigationTools.readTechniqueFile
        #expect(tool.type == "function")
    }

    @Test("Tool function has required fields")
    func toolFunctionHasRequiredFields() {
        let tool = ResourcesNavigationTools.readTechniqueFile
        #expect(tool.function.name == "read_technique_file")
        #expect(tool.function.description.isEmpty == false)
        #expect(tool.function.parameters.type == "object")
    }

    @Test("JSONSchema can be encoded to JSON")
    func jsonSchemaCanBeEncoded() throws {
        let schema = JSONSchema(
            type: "object",
            properties: [
                "filename": JSONSchemaProperty(type: "string", description: "File name")
            ],
            required: ["filename"]
        )

        let data = try JSONEncoder().encode(schema)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json != nil)
        #expect(json?["type"] as? String == "object")
        #expect((json?["required"] as? [String])?.contains("filename") == true)
    }

    @Test("JSONSchemaProperty encodes enum values correctly")
    func jsonSchemaPropertyEncodesEnum() throws {
        let prop = JSONSchemaProperty(
            type: "string",
            description: "Stroke type",
            enumValues: ["freestyle", "backstroke", "breaststroke", "butterfly"]
        )

        let data = try JSONEncoder().encode(prop)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["type"] as? String == "string")
        #expect((json?["enum"] as? [String])?.count == 4)
    }

    // MARK: - ResourcesNavigationTools Tests

    @Test("ResourcesNavigationTools has 4 tools")
    func resourcesNavigationToolsCount() {
        #expect(ResourcesNavigationTools.all.count == 4)
    }

    @Test("read_technique_file has required filename parameter")
    func readTechniqueFileParameters() {
        let tool = ResourcesNavigationTools.readTechniqueFile
        #expect(tool.function.parameters.properties["filename"] != nil)
        #expect(tool.function.parameters.required?.contains("filename") == true)
    }

    @Test("list_technique_files has optional stroke parameter")
    func listTechniqueFilesParameters() {
        let tool = ResourcesNavigationTools.listTechniqueFiles
        #expect(tool.function.parameters.properties["stroke"] != nil)
        #expect(tool.function.parameters.required == nil || tool.function.parameters.required?.isEmpty == true)
        #expect(tool.function.parameters.properties["stroke"]?.enumValues?.count == 4)
    }

    @Test("search_content has required query parameter")
    func searchContentParameters() {
        let tool = ResourcesNavigationTools.searchContent
        #expect(tool.function.parameters.properties["query"] != nil)
        #expect(tool.function.parameters.required?.contains("query") == true)
    }

    @Test("get_related_techniques has required filename parameter")
    func getRelatedTechniquesParameters() {
        let tool = ResourcesNavigationTools.getRelatedTechniques
        #expect(tool.function.parameters.properties["filename"] != nil)
        #expect(tool.function.parameters.required?.contains("filename") == true)
    }

    // MARK: - UserDataTools Tests

    @Test("UserDataTools has 4 tools")
    func userDataToolsCount() {
        #expect(UserDataTools.all.count == 4)
    }

    @Test("get_user_profile has no parameters")
    func getUserProfileParameters() {
        let tool = UserDataTools.getUserProfile
        #expect(tool.function.parameters.properties.isEmpty)
        #expect(tool.function.parameters.required == nil)
    }

    @Test("get_training_history has optional parameters")
    func getTrainingHistoryParameters() {
        let tool = UserDataTools.getTrainingHistory
        #expect(tool.function.parameters.properties["days"] != nil)
        #expect(tool.function.parameters.properties["include_goals"] != nil)
        #expect(tool.function.parameters.required == nil)
    }

    @Test("get_active_goals has no parameters")
    func getActiveGoalsParameters() {
        let tool = UserDataTools.getActiveGoals
        #expect(tool.function.parameters.properties.isEmpty)
    }

    @Test("get_training_calendar has optional weeks parameter")
    func getTrainingCalendarParameters() {
        let tool = UserDataTools.getTrainingCalendar
        #expect(tool.function.parameters.properties["weeks"] != nil)
        #expect(tool.function.parameters.properties["weeks"]?.type == "integer")
    }

    // MARK: - AllTools Tests

    @Test("AllTools combines both tool sets")
    func allToolsCount() {
        #expect(AllTools.all.count == 8)
    }

    @Test("AllTools contains expected tool names")
    func allToolNames() {
        let names = AllTools.all.map { $0.function.name }
        #expect(names.contains("read_technique_file"))
        #expect(names.contains("list_technique_files"))
        #expect(names.contains("search_content"))
        #expect(names.contains("get_related_techniques"))
        #expect(names.contains("get_user_profile"))
        #expect(names.contains("get_training_history"))
        #expect(names.contains("get_active_goals"))
        #expect(names.contains("get_training_calendar"))
    }

    // MARK: - ToolChoice Tests

    @Test("ToolChoice auto encodes to string")
    func toolChoiceAutoEncoding() throws {
        let choice = ToolChoice.auto
        let data = try JSONEncoder().encode(choice)
        #expect(String(data: data, encoding: .utf8) == "\"auto\"")
    }

    @Test("ToolChoice none encodes to string")
    func toolChoiceNoneEncoding() throws {
        let choice = ToolChoice.none
        let data = try JSONEncoder().encode(choice)
        #expect(String(data: data, encoding: .utf8) == "\"none\"")
    }

    @Test("ToolChoice required encodes to string")
    func toolChoiceRequiredEncoding() throws {
        let choice = ToolChoice.required
        let data = try JSONEncoder().encode(choice)
        #expect(String(data: data, encoding: .utf8) == "\"required\"")
    }

    @Test("ToolChoice specific encodes to object")
    func toolChoiceSpecificEncoding() throws {
        let choice = ToolChoice.specific("read_technique_file")
        let data = try JSONEncoder().encode(choice)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["type"] as? String == "function")
        #expect((json?["function"] as? [String: Any])?["name"] as? String == "read_technique_file")
    }

    // MARK: - ToolCall Tests

    @Test("ToolCall can be created with all fields")
    func toolCallCreation() {
        let function = ToolCallFunction(name: "test_tool", arguments: "{\"param\": \"value\"}")
        let toolCall = ToolCall(id: "call_123", type: "function", function: function)

        #expect(toolCall.id == "call_123")
        #expect(toolCall.type == "function")
        #expect(toolCall.function.name == "test_tool")
        #expect(toolCall.function.arguments == "{\"param\": \"value\"}")
    }

    @Test("ToolCall can be decoded from JSON")
    func toolCallDecoding() throws {
        let json = """
        {
            "id": "call_abc123",
            "type": "function",
            "function": {
                "name": "read_technique_file",
                "arguments": "{\\"filename\\": \\"freestyle.md\\"}"
            }
        }
        """.data(using: .utf8)!

        let toolCall = try JSONDecoder().decode(ToolCall.self, from: json)
        #expect(toolCall.id == "call_abc123")
        #expect(toolCall.function.name == "read_technique_file")
    }

    // MARK: - ToolError Tests

    @Test("ToolError unknownTool has correct description")
    func toolErrorUnknownTool() {
        let error = ToolError.unknownTool("bad_tool")
        #expect(error.description == "Unknown tool: bad_tool")
    }

    @Test("ToolError missingParameter has correct description")
    func toolErrorMissingParameter() {
        let error = ToolError.missingParameter("filename")
        #expect(error.description == "Missing required parameter: filename")
    }

    @Test("ToolError invalidParameter has correct description")
    func toolErrorInvalidParameter() {
        let error = ToolError.invalidParameter("stroke", "invalid")
        #expect(error.description == "Invalid parameter stroke: invalid")
    }

    @Test("ToolError executionError has correct description")
    func toolErrorExecutionError() {
        let error = ToolError.executionError("Something went wrong")
        #expect(error.description == "Tool execution error: Something went wrong")
    }

    @Test("ToolError is Equatable")
    func toolErrorEquatable() {
        let error1 = ToolError.unknownTool("test")
        let error2 = ToolError.unknownTool("test")
        let error3 = ToolError.missingParameter("test")

        #expect(error1 == error2)
        #expect(error1 != error3)
    }
}