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
    public var strict: Bool?  // DeepSeek V4 strict mode

    public init(name: String, description: String, parameters: JSONSchema, strict: Bool? = nil) {
        self.name = name
        self.description = description
        self.parameters = parameters
        self.strict = strict
    }
}

public struct JSONSchema: Codable, Hashable, Sendable {
    public var type: String
    public var properties: [String: JSONSchemaProperty]
    public var required: [String]?
    public var additionalProperties: Bool?  // DeepSeek V4 strict mode requires false

    public init(type: String = "object", properties: [String: JSONSchemaProperty], required: [String]? = nil, additionalProperties: Bool? = nil) {
        self.type = type
        self.properties = properties
        self.required = required
        self.additionalProperties = additionalProperties
    }

    private enum CodingKeys: String, CodingKey {
        case type, properties, required, additionalProperties
    }

    public nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        properties = try container.decode([String: JSONSchemaProperty].self, forKey: .properties)
        required = try container.decodeIfPresent([String].self, forKey: .required)
        additionalProperties = try container.decodeIfPresent(Bool.self, forKey: .additionalProperties)
    }

    public nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(properties, forKey: .properties)
        try container.encodeIfPresent(required, forKey: .required)
        try container.encodeIfPresent(additionalProperties, forKey: .additionalProperties)
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
            - Each sub-file has competitive metrics with tiered targets

            STRATEGY: read_technique_file("{stroke}.md") → find technique at user's level → read sub-technique.
            """,
            parameters: JSONSchema(
                properties: [
                    "filename": JSONSchemaProperty(
                        type: "string",
                        description: "File to read. Start with main files (freestyle.md) or read specific technique (freestyle-02-flutter-kick). Main files show difficulty-ranked technique tables."
                    )
                ],
                required: ["filename"],
                additionalProperties: false
            ),
            strict: false  // Disabled for standard endpoint compatibility
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
                ],
                required: [],  // No required params - stroke is optional
                additionalProperties: false
            ),
            strict: false  // Cannot use strict with optional params (DeepSeek requires all properties in required array)
        )
    )

    public static let searchContent = Tool(
        function: ToolFunction(
            name: "search_content",
            description: "Search for keywords across technique files. Returns structured matches organized by section (title, key_points, drills, competitive_drills) rather than raw text excerpts. Use get_technique_drills when you only need drills.",
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
                required: ["query"],
                additionalProperties: false
            ),
            strict: false  // Disabled for standard endpoint compatibility
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
                required: ["filename"],
                additionalProperties: false
            ),
            strict: false  // Disabled for standard endpoint compatibility
        )
    )

    public static let getExternalFocusCues = Tool(
        function: ToolFunction(
            name: "get_external_focus_cues",
            description: """
            Get external focus cues for swimming technique issues. External cues are short, actionable prompts coaches use to help swimmers feel and execute correct movement patterns.

            Returns cues organized by stroke and issue type (e.g. Freestyle → Hips Sinking → ["Stay on top of the water", "Speedboat", "Flat on the water"]). Each issue has 5-8 different cue types: images, feelings, actions, targets, rhythms, and simple directions.

            REQUIRED: Call this tool when generating key points, mistakes to avoid, or coaching tips for any stroke technique. Use the returned cues to make your suggestions more concrete and swimmer-friendly. Match the issue (e.g. "head too high", "no body rotation") to the swimmer's specific technique problem.

            STROKES COVERED: Freestyle (9 issues), Backstroke (6), Breaststroke (8), Butterfly (3), Starts (3), Turns (4).
            """,
            parameters: JSONSchema(
                properties: [
                    "stroke": JSONSchemaProperty(
                        type: "string",
                        description: "Stroke to get cues for. Use 'starts' or 'turns' for start/turn cues.",
                        enumValues: ["freestyle", "backstroke", "breaststroke", "butterfly", "starts", "turns"]
                    ),
                    "issue": JSONSchemaProperty(
                        type: "string",
                        description: "Optional: specific issue to filter (e.g. 'hips sinking', 'head too high'). Leave empty to see all issues for the stroke."
                    )
                ],
                required: ["stroke"],
                additionalProperties: false
            ),
            strict: true
        )
    )

    public static let getTechniqueDrills = Tool(
        function: ToolFunction(
            name: "get_technique_drills",
            description: """
            Extract only the drills section from a technique markdown file. Returns specific drills and competitive drills with tiered targets. Use this when you need drill names and targets for training plan generation — it's faster and more focused than read_technique_file.

            Call for drillSet (standard technique work from stroke technique files). For secondarySet, use read_evidence_drills only when the session's coaching style calls for an evidence/exploration block; otherwise omit secondarySet or use signature sets from read_coach_reference. Returns drill names, descriptions, and tiered targets (Beginner/Intermediate/Advanced/Elite).

            USAGE: get_technique_drills("freestyle-02-flutter-kick") → drills for that technique
            get_technique_drills("freestyle.md") → technique table + any drills from main file
            """,
            parameters: JSONSchema(
                properties: [
                    "filename": JSONSchemaProperty(
                        type: "string",
                        description: "Technique file to extract drills from (e.g., 'freestyle-02-flutter-kick', 'backstroke-03-flutter-kick')"
                    )
                ],
                required: ["filename"],
                additionalProperties: false
            ),
            strict: true
        )
    )

    public static var all: [Tool] {
        [readTechniqueFile, listTechniqueFiles, searchContent, getRelatedTechniques, getExternalFocusCues, getTechniqueDrills]
    }
}

// MARK: - User Data Tools

public enum UserDataTools {
    public static let getUserProfile = Tool(
        function: ToolFunction(
            name: "get_user_profile",
            description: "Get the current swimmer's profile including age, skill level, personal best times, weekly session target, preferred strokes, and training goals.",
            parameters: JSONSchema(
                properties: [:],
                required: [],
                additionalProperties: false
            ),
            strict: false  // Disabled for standard endpoint compatibility
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
                ],
                required: [],  // All params optional
                additionalProperties: false
            ),
            strict: false  // Cannot use strict with optional params
        )
    )

    public static let getActiveGoals = Tool(
        function: ToolFunction(
            name: "get_active_goals",
            description: "Get currently active/pending goals from the swimmer's training notes. Shows what techniques they are currently working on.",
            parameters: JSONSchema(
                properties: [:],
                required: [],
                additionalProperties: false
            ),
            strict: false  // Disabled for standard endpoint compatibility
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
                ],
                required: [],  // All params optional
                additionalProperties: false
            ),
            strict: false  // Cannot use strict with optional params
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
                ],
                required: [],  // All params optional
                additionalProperties: false
            ),
            strict: false  // Cannot use strict with optional params
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
                ],
                required: [],  // All params optional
                additionalProperties: false
            ),
            strict: false  // Cannot use strict with optional params
        )
    )

    public static let getTierGuidance = Tool(
        function: ToolFunction(
            name: "get_tier_guidance",
            description: """
            Get training guidance based on the swimmer's competitive tier.

            Returns:
            - Current tier and sub-tier (Pre-Competitive A/B/C, Bronze 1/2/3, Silver 1/2/3, Gold, Senior, National)
            - Recommended weekly distance range in meters
            - Recommended per-session distance range
            - Zone distribution percentages (Zone 0-6) appropriate for the tier
            - Training focus priorities
            - Practices per week recommendation

            This guidance comes from the USA Swimming club training structure, which defines
            age-appropriate and developmentally-appropriate training volumes and intensities.

            REQUIRED: Call this before generating training plans to ensure:
            - Session total distance aligns with per-session guidance
            - Weekly total aligns with weekly distance recommendation
            - Zone distribution matches tier-appropriate intensity levels
            - Training focus matches developmental stage

            For detailed tier background (time standards, sub-tier breakdowns, promotion triggers,
            coaching philosophy), call read_usa_swimming_structure() for the full document.
            """,
            parameters: JSONSchema(
                properties: [:],
                required: [],
                additionalProperties: false
            ),
            strict: false  // Disabled for standard endpoint compatibility
        )
    )

    public static let readUSASwimmingStructure = Tool(
        function: ToolFunction(
            name: "read_usa_swimming_structure",
            description: """
            Read the USA Swimming club training structure reference document.

            This document is a condensed, LLM-optimized reference extracted from the full
            USA Swimming club training guide. It contains the factual data (tables, criteria,
            distributions) without commentary or citations.

            WHAT IT COVERS:
            - 6 training tiers: Pre-Competitive → Bronze → Silver → Gold → Senior → National
            - For each tier: age range, practices/week, practice duration, weekly distance,
              training focus breakdown, and training zone distribution (Zone 0-6)
            - Sub-tier details: Pre-Comp A/B/C, Bronze 1/2/3, Silver 1/2/3
            - USA Swimming time standards (B/BB/A/AA/AAA/AAAA) for boys and girls,
              ages 10&U through 17-18, for 50/100/200 Free, 100 Back/Breast/Fly (SCY)
            - Volume progression by age and LTAD stage mapping

            HOW TO USE:
            - Call with section="summary" for the quick-reference overview table
            - Call with section="zones" for Zone 0-6 distribution across all tiers
            - Call with section="subtiers" for Pre-Comp/Bronze/Silver sub-tier detail tables
            - Call with section="standards" for the full time-standards tables (boys + girls)
            - Omit section (or use "all") for a compact overview with summary, zones, and volume

            TYPICAL USAGE: When generating a plan for a Bronze-tier swimmer, call
            read_usa_swimming_structure(section:"subtiers") to get Bronze 1/2/3 details and
            read_usa_swimming_structure(section:"zones") for the zone distribution — you don't
            need the Gold/Senior/National sections. Use section parameter to read only what's
            relevant to the swimmer's tier and avoid wasting context on irrelevant tiers.
            """,
            parameters: JSONSchema(
                properties: [
                    "section": JSONSchemaProperty(
                        type: "string",
                        description: "Optional section to focus on: 'summary', 'subtiers', 'zones', 'standards', 'all'",
                        enumValues: ["summary", "subtiers", "zones", "standards", "all"]
                    )
                ],
                required: [],
                additionalProperties: false
            ),
            strict: false  // Cannot use strict with optional params
        )
    )

    public static let readEvidenceDrills = Tool(
        function: ToolFunction(
            name: "read_evidence_drills",
            description: """
            Read evidence-based swimming drills from the research-backed drill library.

            Returns drills organized by stroke (freestyle, backstroke, breaststroke, butterfly) with:
            - Drill code (e.g., F1, B3, BR2, FL5)
            - Evidence base (research citation)
            - Distance and equipment needed
            - Level adjustments (Beginner/Intermediate/Advanced/Elite)
            - Progression guidance (4-week plans)
            - When to use each drill type

            Drill types available:
            - Tempo Ladder: Stroke rate progression (Z3→Z6) — race-finish speed
            - Roll Explorer: Rotation angle variations — finding efficient range
            - Differential Practice: Variable practice set — learning new patterns
            - Build & Hold: Race-finish simulation (Z4→Z5) — lactate tolerance
            - Constraints Circuit: Constraint-led approach — technique refinement
            - Timing/Phase Explorer: Phase isolation — timing refinement (breast/fly)

            Use when secondarySet should be an evidence-based exploration block (Differential Learning, Salo, Touretski, Bowman race-prep, etc.). For standard drillSet use get_technique_drills; for style-driven main/drill work use read_coach_reference. secondarySet is optional — omit when user coaching styles do not call for it.
            After choosing a drill code (F1, B2, etc.), call again with drill="F1" (etc.) to load the full set table before writing JSON.

            When secondarySet uses evidence drills: exactly ONE drill code per session. One JSON set object per numbered table row (#). Never collapse rows into improvised hybrid item strings.

            USAGE: read_evidence_drills(stroke="freestyle") → all freestyle evidence drills
            read_evidence_drills(stroke="freestyle", drill="F1") → full details for one drill
            read_evidence_drills(stroke="all") → quick reference index only
            """,
            parameters: JSONSchema(
                properties: [
                    "stroke": JSONSchemaProperty(
                        type: "string",
                        description: "Stroke to get evidence drills for. Use 'all' for quick index only.",
                        enumValues: ["freestyle", "backstroke", "breaststroke", "butterfly", "all"]
                    ),
                    "drill": JSONSchemaProperty(
                        type: "string",
                        description: "Optional: specific drill code (e.g., 'F1', 'B3', 'BR2', 'FL5'). Omit to get all drills for the stroke."
                    )
                ],
                required: ["stroke"],
                additionalProperties: false
            ),
            strict: true
        )
    )

    public static let readCoachReference = Tool(
        function: ToolFunction(
            name: "read_coach_reference",
            description: """
            Read swimming-coach-role-reference.md — coaching styles by swimmer tier (YB, YD, NA, INT, ADV, ELT, SPT, DST).

            Returns tier-specific recommended styles (with When to Use), Focus, Use, Avoid, and signature set ideas. Use to decide how to structure drillSet, mainSet, and whether to include secondarySet.

            Call read_coach_reference(tier="INT") for the full tier section matching the swimmer.
            Optional section: decision_tree, compatibility, signature_sets, evidence_mapping.

            User-selected coaching styles are embedded in the plan prompt — align session design with those choices.
            """,
            parameters: JSONSchema(
                properties: [
                    "tier": JSONSchemaProperty(
                        type: "string",
                        description: "Coach tier code: YB, YD, NA, INT, ADV, ELT, SPT, DST",
                        enumValues: ["YB", "YD", "NA", "INT", "ADV", "ELT", "SPT", "DST"]
                    ),
                    "section": JSONSchemaProperty(
                        type: "string",
                        description: "Optional: decision_tree, compatibility, signature_sets, evidence_mapping",
                        enumValues: ["decision_tree", "compatibility", "signature_sets", "evidence_mapping"]
                    )
                ],
                required: [],
                additionalProperties: false
            ),
            strict: false
        )
    )

    public static let getDryLandExercises = Tool(
        function: ToolFunction(
            name: "get_dry_land_exercises",
            description: """
            Get available dry land exercises for a specific stroke. Returns exercise IDs, names, categories, default sets/reps, and stroke-specific focus points.

            REQUIRED for Phase 3: Call this BEFORE generating dry land exercises. You must ONLY use exercises returned by this tool - do NOT invent or create new exercises.

            Return the exercise ID (e.g. 'plank-hold') in your response. The app will match IDs to full drill details including focus points.
            """,
            parameters: JSONSchema(
                properties: [
                    "stroke": JSONSchemaProperty(
                        type: "string",
                        description: "Stroke to get exercises for",
                        enumValues: ["freestyle", "backstroke", "breaststroke", "butterfly"]
                    )
                ],
                required: ["stroke"],
                additionalProperties: false
            ),
            strict: true
        )
    )

    public static var all: [Tool] {
        [getUserProfile, getTrainingHistory, getActiveGoals, getTrainingCalendar, getCSSInfo, readIntervalResearch, getTierGuidance, readUSASwimmingStructure, readEvidenceDrills, readCoachReference, getDryLandExercises]
    }
}

// MARK: - All Available Tools

public enum AllTools {
    public static var all: [Tool] {
        ResourcesNavigationTools.all + UserDataTools.all
    }
}

// MARK: - Training Plan Tools (CSS + Interval Research + Tier Guidance)

public enum TrainingPlanTools {
    public static var all: [Tool] {
        UserDataTools.all
    }
}

// MARK: - Tool Error

public enum ToolError: Error, Equatable, CustomStringConvertible, LocalizedError {
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

    public var errorDescription: String? { description }
}