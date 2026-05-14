import Foundation

// MARK: - Combined Tool Executor

public final class CombinedToolExecutor: Sendable {
    let contentLoader: BundleContentLoader
    let markdownParser = TechniqueMarkdownParser()
    let profile: UserProfile?
    let notes: [TrainingNote]
    /// Reference date for time-relative queries (e.g., "last N days", "calendar").
    /// Defaults to Date() so standalone tool calls use current time.
    let referenceDate: Date

    public init(
        contentLoader: BundleContentLoader,
        profile: UserProfile?,
        notes: [TrainingNote],
        referenceDate: Date? = nil
    ) {
        self.contentLoader = contentLoader
        self.profile = profile
        self.notes = notes
        self.referenceDate = referenceDate ?? Date()
    }

    public func execute(_ toolCall: ToolCall) async throws -> String {
        let args = try parseArguments(toolCall)

        switch toolCall.function.name {
        // Resources navigation tools
        case "list_technique_files":
            return try listTechniqueFiles(stroke: args["stroke"] as? String)
        case "read_technique_file":
            return try readTechniqueFile(filename: args["filename"] as? String)
        case "search_content":
            return try searchContent(query: args["query"] as? String, stroke: args["stroke"] as? String)
        case "get_related_techniques":
            return try getRelatedTechniques(filename: args["filename"] as? String)

        // User data tools
        case "get_user_profile":
            return try getUserProfile()
        case "get_training_history":
            return try getTrainingHistory(
                days: args["days"] as? Int ?? 7,
                includeGoals: args["include_goals"] as? Bool ?? true
            )
        case "get_active_goals":
            return try getActiveGoals()
        case "get_training_calendar":
            return try getTrainingCalendar(weeks: args["weeks"] as? Int ?? 4)

        // CSS and interval training tools
        case "get_css_info":
            return try getCSSInfo(stroke: args["stroke"] as? String)
        case "read_interval_research":
            return try readIntervalResearch(section: args["section"] as? String)

        // Tier guidance tool
        case "get_tier_guidance":
            return try getTierGuidance()

        // USA Swimming structure document
        case "read_usa_swimming_structure":
            return try readUSASwimmingStructure(section: args["section"] as? String)

        // Dry land exercises tool
        case "get_dry_land_exercises":
            return try getDryLandExercises(stroke: args["stroke"] as? String)

        // Evidence-based drills tool
        case "read_evidence_drills":
            return try readEvidenceDrills(stroke: args["stroke"] as? String, drill: args["drill"] as? String)

        // Technique drills extraction tool
        case "get_technique_drills":
            return try getTechniqueDrills(filename: args["filename"] as? String)

        // External focus cues tool
        case "get_external_focus_cues":
            return try getExternalFocusCues(
                stroke: args["stroke"] as? String,
                issue: args["issue"] as? String
            )

        default:
            throw ToolError.unknownTool(toolCall.function.name)
        }
    }
    func parseArguments(_ toolCall: ToolCall) throws -> [String: Any] {
        guard let data = toolCall.function.arguments.data(using: .utf8) else {
            throw ToolError.executionError("Could not decode arguments")
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ToolError.executionError("Arguments are not valid JSON")
        }
        return json
    }

    func encodeJSON(_ value: Any) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: value, options: [])
        guard let string = String(data: data, encoding: .utf8) else {
            throw ToolError.executionError("Could not encode result as JSON")
        }
        return string
    }
}
