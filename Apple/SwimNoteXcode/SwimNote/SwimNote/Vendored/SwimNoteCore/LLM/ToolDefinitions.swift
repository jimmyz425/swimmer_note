import Foundation

// MARK: - Tool Types (OpenAI Function Calling Schema)

public struct Tool: Codable, Hashable, Sendable {
    public var type: String = "function"
    public var function: ToolFunction

    public init(function: ToolFunction) {
        self.function = function
    }
}

public struct ToolFunction: Codable, Hashable, Sendable {
    public var name: String
    public var description: String
    public var parameters: JSONSchema

    public init(name: String, description: String, parameters: JSONSchema) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }
}

public struct JSONSchema: Codable, Hashable, Sendable {
    public var type: String
    public var properties: [String: JSONSchemaProperty]
    public var required: [String]?

    public init(type: String = "object", properties: [String: JSONSchemaProperty], required: [String]? = nil) {
        self.type = type
        self.properties = properties
        self.required = required
    }

    private enum CodingKeys: String, CodingKey {
        case type, properties, required
    }

    public nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        properties = try container.decode([String: JSONSchemaProperty].self, forKey: .properties)
        required = try container.decodeIfPresent([String].self, forKey: .required)
    }

    public nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(properties, forKey: .properties)
        try container.encodeIfPresent(required, forKey: .required)
    }
}

public struct JSONSchemaProperty: Codable, Hashable, Sendable {
    public var type: String
    public var description: String?
    public var enumValues: [String]?

    enum CodingKeys: String, CodingKey {
        case type
        case description
        case enumValues = "enum"
    }

    public init(type: String, description: String? = nil, enumValues: [String]? = nil) {
        self.type = type
        self.description = description
        self.enumValues = enumValues
    }

    public nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        enumValues = try container.decodeIfPresent([String].self, forKey: .enumValues)
    }

    public nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(enumValues, forKey: .enumValues)
    }
}

// MARK: - Tool Call Types

public nonisolated struct ToolCall: Codable, Hashable, Sendable {
    public var id: String
    public var type: String
    public var function: ToolCallFunction

    public init(id: String, type: String = "function", function: ToolCallFunction) {
        self.id = id
        self.type = type
        self.function = function
    }

    private enum CodingKeys: String, CodingKey {
        case id, type, function
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(String.self, forKey: .type)
        function = try container.decode(ToolCallFunction.self, forKey: .function)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(function, forKey: .function)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(type)
        hasher.combine(function)
    }

    public static func == (lhs: ToolCall, rhs: ToolCall) -> Bool {
        lhs.id == rhs.id && lhs.type == rhs.type && lhs.function == rhs.function
    }
}

public nonisolated struct ToolCallFunction: Codable, Hashable, Sendable {
    public var name: String
    public var arguments: String

    public init(name: String, arguments: String) {
        self.name = name
        self.arguments = arguments
    }

    private enum CodingKeys: String, CodingKey {
        case name, arguments
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        arguments = try container.decode(String.self, forKey: .arguments)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(arguments, forKey: .arguments)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(arguments)
    }

    public static func == (lhs: ToolCallFunction, rhs: ToolCallFunction) -> Bool {
        lhs.name == rhs.name && lhs.arguments == rhs.arguments
    }
}

// MARK: - Tool Choice

public enum ToolChoice: Codable, Hashable, Sendable {
    case auto
    case none
    case required
    case specific(String)

    public nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .auto:
            try container.encode("auto")
        case .none:
            try container.encode("none")
        case .required:
            try container.encode("required")
        case .specific(let name):
            try container.encode(SpecificToolChoice(type: "function", function: ToolChoiceFunction(name: name)))
        }
    }

    public nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            switch string {
            case "auto": self = .auto
            case "none": self = .none
            case "required": self = .required
            default: self = .specific(string)
            }
        } else {
            let choice = try container.decode(SpecificToolChoiceDecodable.self)
            self = .specific(choice.function.name)
        }
    }
}

private struct SpecificToolChoice: Encodable {
    let type: String
    let function: ToolChoiceFunction

    nonisolated init(type: String, function: ToolChoiceFunction) {
        self.type = type
        self.function = function
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(function, forKey: .function)
    }

    private enum CodingKeys: String, CodingKey {
        case type, function
    }
}

private struct SpecificToolChoiceDecodable: Decodable {
    let function: ToolChoiceFunction

    private enum CodingKeys: String, CodingKey {
        case function
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        function = try container.decode(ToolChoiceFunction.self, forKey: .function)
    }
}

private struct ToolChoiceFunction: Encodable, Decodable {
    let name: String

    nonisolated init(name: String) {
        self.name = name
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        // Try as nested object
        if let nested = try? container.decode(NestedFunction.self) {
            name = nested.name
        } else {
            name = try container.decode(String.self)
        }
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
    }

    private enum CodingKeys: String, CodingKey {
        case name
    }

    private struct NestedFunction: Decodable {
        let name: String

        private enum CodingKeys: String, CodingKey {
            case name
        }

        nonisolated init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
        }
    }
}

// MARK: - Predefined Tools for Resources Navigation

public enum ResourcesNavigationTools {
    public static let readTechniqueFile = Tool(
        function: ToolFunction(
            name: "read_technique_file",
            description: """
            Read a technique markdown file. Files are organized as a wiki with difficulty rankings:

            MAIN STROKE FILES (start here):
            - 'freestyle.md' → table of 9 techniques ranked Easiest→Hard (1-9)
            - 'backstroke.md', 'breaststroke.md', 'butterfly.md' → same structure

            TECHNIQUE NUMBERING = DIFFICULTY:
            - 01-02: Easiest/Easy (body position, basic kick) → for Beginners
            - 03-04: Moderate (breathing, rotation) → for Intermediate
            - 05-07: Moderate-Hard (arm entry, recovery, timing) → for Advanced
            - 08-09: Hard (catch EVF, pull phase) → for Competitive/Elite

            SUB-TECHNIQUE FILES (follow links):
            - 'freestyle-02-flutter-kick.md' → drills + tiered targets (Beginner→Elite)
            - 'freestyle-08-catch-evf.md' → advanced technique with competitive metrics

            PROGRESSION GUIDANCE:
            - Read main file → see technique table with difficulty
            - Pick technique number matching user's skill level
            - Each sub-file has competitive drills with tiered targets

            STRATEGY: read_technique_file("{stroke}.md") → find technique at user's level → read sub-technique.
            """,
            parameters: JSONSchema(
                properties: [
                    "filename": JSONSchemaProperty(
                        type: "string",
                        description: "File to read. Start with main files (freestyle.md) or read specific technique (freestyle-02-flutter-kick). Main files show difficulty-ranked technique tables."
                    )
                ],
                required: ["filename"]
            )
        )
    )

    public static let listTechniqueFiles = Tool(
        function: ToolFunction(
            name: "list_technique_files",
            description: "List all technique files. Prefer reading main stroke files first to see difficulty-ranked technique tables.",
            parameters: JSONSchema(
                properties: [
                    "stroke": JSONSchemaProperty(
                        type: "string",
                        description: "Optional stroke filter: freestyle, backstroke, breaststroke, butterfly",
                        enumValues: ["freestyle", "backstroke", "breaststroke", "butterfly"]
                    )
                ]
            )
        )
    )

    public static let searchContent = Tool(
        function: ToolFunction(
            name: "search_content",
            description: "Search for keywords across technique files. Returns matching files with excerpts.",
            parameters: JSONSchema(
                properties: [
                    "query": JSONSchemaProperty(
                        type: "string",
                        description: "Search terms (e.g., 'kick', 'breathing', 'dry-land')"
                    ),
                    "stroke": JSONSchemaProperty(
                        type: "string",
                        description: "Optional stroke filter",
                        enumValues: ["freestyle", "backstroke", "breaststroke", "butterfly"]
                    )
                ],
                required: ["query"]
            )
        )
    )

    public static let getRelatedTechniques = Tool(
        function: ToolFunction(
            name: "get_related_techniques",
            description: "Get related techniques and navigation links from a technique file. Shows prev/next files in the progression.",
            parameters: JSONSchema(
                properties: [
                    "filename": JSONSchemaProperty(
                        type: "string",
                        description: "The filename to find related techniques for"
                    )
                ],
                required: ["filename"]
            )
        )
    )

    public static var all: [Tool] {
        [readTechniqueFile, listTechniqueFiles, searchContent, getRelatedTechniques]
    }
}

// MARK: - User Data Tools

public enum UserDataTools {
    public static let getUserProfile = Tool(
        function: ToolFunction(
            name: "get_user_profile",
            description: "Get the current swimmer's profile including age, skill level, personal best times, weekly session target, preferred strokes, and training goals.",
            parameters: JSONSchema(
                properties: [:]
            )
        )
    )

    public static let getTrainingHistory = Tool(
        function: ToolFunction(
            name: "get_training_history",
            description: "Get past training notes to understand what the swimmer has been working on. Returns notes with dates, stroke focus, goals, and observations.",
            parameters: JSONSchema(
                properties: [
                    "days": JSONSchemaProperty(
                        type: "integer",
                        description: "Number of past days to retrieve (default 7, max 30)"
                    ),
                    "include_goals": JSONSchemaProperty(
                        type: "boolean",
                        description: "Include goals from each session (default true)"
                    )
                ]
            )
        )
    )

    public static let getActiveGoals = Tool(
        function: ToolFunction(
            name: "get_active_goals",
            description: "Get currently active/pending goals from the swimmer's training notes. Shows what techniques they are currently working on.",
            parameters: JSONSchema(
                properties: [:]
            )
        )
    )

    public static let getTrainingCalendar = Tool(
        function: ToolFunction(
            name: "get_training_calendar",
            description: "Get a calendar view showing which days had training sessions. Useful for checking training frequency and patterns.",
            parameters: JSONSchema(
                properties: [
                    "weeks": JSONSchemaProperty(
                        type: "integer",
                        description: "Number of weeks to show (default 4)"
                    )
                ]
            )
        )
    )

    public static let getCSSInfo = Tool(
        function: ToolFunction(
            name: "get_css_info",
            description: """
            Get the swimmer's Critical Swim Speed (CSS) test results and training paces.

            CSS is the theoretical pace a swimmer can maintain indefinitely - the aerobic threshold.
            Training zones are calculated from CSS pace:

            Zone 0: Recovery (CSS +20-30s/100m)
            Zone 1: Aerobic Base (CSS +10-15s/100m)
            Zone 2: Aerobic Endurance (CSS +5-10s/100m)
            Zone 3: Tempo (CSS +0-5s/100m)
            Zone 4: Lactate Threshold (CSS to -2s/100m)
            Zone 5: VO2max (CSS -3-6s/100m)
            Zone 6: Sprint (Race pace)

            Use this to set accurate interval times and training zone targets.
            Call this before generating training plans to ensure zone-appropriate pacing.
            """,
            parameters: JSONSchema(
                properties: [
                    "stroke": JSONSchemaProperty(
                        type: "string",
                        description: "Optional stroke filter (freestyle, backstroke, breaststroke). Default: freestyle.",
                        enumValues: ["freestyle", "backstroke", "breaststroke"]
                    )
                ]
            )
        )
    )

    public static let readIntervalResearch = Tool(
        function: ToolFunction(
            name: "read_interval_research",
            description: """
            Read the comprehensive interval training research document.

            This document contains:
            - Training zones by purpose (Zone 0-6 with CSS offsets, heart rate targets, volume recommendations)
            - Interval calculation methods (CSS-based, heart rate based, send-off times)
            - Periodization guidance (macrocycle phases, progression over training cycle)
            - Event-specific considerations (sprint vs distance vs mid-distance)
            - Swimmer level adjustments (beginner vs intermediate vs advanced vs elite)
            - Sample sets for each zone with detailed rest intervals
            - Volume recommendations by skill level

            CONTENT SECTIONS:
            - Section 2: Training Zones (Zone 0-6 details with pace targets, rest intervals, sample sets)
            - Section 3: Interval Calculation (CSS formulas, send-off times)
            - Section 4: Periodization (macrocycle phases, combining interval types)
            - Section 5: Event-Specific (sprint, mid-distance, distance considerations)
            - Section 6: Swimmer Level Adjustments (volume, intensity modifications by skill)

            REQUIRED: Call this document when generating training plans.
            Use it to determine: session volume, zone selection, rest intervals, progression.
            """,
            parameters: JSONSchema(
                properties: [
                    "section": JSONSchemaProperty(
                        type: "string",
                        description: "Optional section to focus on: 'zones', 'intervals', 'periodization', 'events', 'levels', 'all'",
                        enumValues: ["zones", "intervals", "periodization", "events", "levels", "all"]
                    )
                ]
            )
        )
    )

    public static var all: [Tool] {
        [getUserProfile, getTrainingHistory, getActiveGoals, getTrainingCalendar, getCSSInfo, readIntervalResearch]
    }
}

// MARK: - All Available Tools

public enum AllTools {
    public static var all: [Tool] {
        ResourcesNavigationTools.all + UserDataTools.all
    }
}

// MARK: - Training Plan Tools (CSS + Interval Research)

public enum TrainingPlanTools {
    public static var all: [Tool] {
        UserDataTools.all + [UserDataTools.getCSSInfo, UserDataTools.readIntervalResearch]
    }
}

// MARK: - Tool Error

public enum ToolError: Error, Equatable, CustomStringConvertible {
    case unknownTool(String)
    case missingParameter(String)
    case invalidParameter(String, String)
    case executionError(String)

    public var description: String {
        switch self {
        case .unknownTool(let name):
            return "Unknown tool: \(name)"
        case .missingParameter(let param):
            return "Missing required parameter: \(param)"
        case .invalidParameter(let param, let value):
            return "Invalid parameter \(param): \(value)"
        case .executionError(let message):
            return "Tool execution error: \(message)"
        }
    }
}