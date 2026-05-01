import Foundation

public struct ToolExecutor: Sendable {
    private let contentLoader: BundleContentLoader
    private let markdownParser = TechniqueMarkdownParser()

    public init(contentLoader: BundleContentLoader) {
        self.contentLoader = contentLoader
    }

    public func execute(_ toolCall: ToolCall) async throws -> String {
        let args = try parseArguments(toolCall)

        switch toolCall.function.name {
        case "list_technique_files":
            return try listTechniqueFiles(stroke: args["stroke"] as? String)
        case "read_technique_file":
            return try readTechniqueFile(filename: args["filename"] as? String)
        case "search_content":
            return try searchContent(query: args["query"] as? String, stroke: args["stroke"] as? String)
        case "get_related_techniques":
            return try getRelatedTechniques(filename: args["filename"] as? String)
        default:
            throw ToolError.unknownTool(toolCall.function.name)
        }
    }

    // MARK: - Tool Implementations

    private func listTechniqueFiles(stroke: String?) throws -> String {
        let allFiles = try contentLoader.listTechniqueMarkdownFiles()

        let filteredFiles: [TechniqueFileInfo]
        if let stroke {
            filteredFiles = allFiles.filter { $0.stroke == stroke }
        } else {
            filteredFiles = allFiles
        }

        let result = filteredFiles.map { file -> [String: String] in
            [
                "filename": file.filename,
                "stroke": file.stroke,
                "title": file.title,
                "difficulty": file.difficulty ?? "unknown"
            ]
        }

        return try encodeJSON(result)
    }

    private func readTechniqueFile(filename: String?) throws -> String {
        guard let filename else {
            throw ToolError.missingParameter("filename")
        }

        let normalizedFilename = filename.hasSuffix(".md") ? filename : "\(filename).md"

        let content = try contentLoader.loadMarkdown(filename: normalizedFilename)
        let parsed = markdownParser.parse(filename: normalizedFilename, rawContent: content)

        let result: [String: Any] = [
            "filename": normalizedFilename,
            "title": parsed.title,
            "overview": parsed.overview,
            "difficulty": parsed.difficulty,
            "key_points": parsed.keyPoints,
            "common_mistakes": parsed.commonMistakes,
            "specific_drills": parsed.specificDrills.map { ["name": $0.name, "description": $0.description] },
            "competitive_drills": parsed.competitiveDrills.map { drill -> [String: Any] in
                [
                    "name": drill.name,
                    "self_check": drill.selfCheck,
                    "tiered_targets": drill.tieredTargets,
                    "competitive_impact": drill.competitiveImpact
                ]
            },
            "related_techniques": parsed.relatedTechniques,
            "prev_file": parsed.prevFile ?? "",
            "next_file": parsed.nextFile ?? ""
        ]

        return try encodeJSON(result)
    }

    private func searchContent(query: String?, stroke: String?) throws -> String {
        guard let query else {
            throw ToolError.missingParameter("query")
        }

        let allFiles = try contentLoader.listTechniqueMarkdownFiles()
        let searchTerms = query.lowercased().split(separator: " ").map(String.init)

        let filteredFiles = allFiles.filter { stroke == nil || $0.stroke == stroke }

        var matches: [[String: Any]] = []

        for file in filteredFiles {
            let content = try contentLoader.loadMarkdown(filename: file.filename)
            let lowercased = content.lowercased()

            // Check if any search term appears
            let hasMatch = searchTerms.contains(where: { term in lowercased.contains(term) })
            if !hasMatch { continue }

            // Find excerpts containing the terms
            let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
            var excerpts: [String] = []

            for line in lines {
                let lineLower = line.lowercased()
                if searchTerms.contains(where: { term in lineLower.contains(term) }) {
                    let excerpt = String(line).trimmingCharacters(in: .whitespaces)
                    if excerpt.count > 10 && excerpts.count < 3 {
                        excerpts.append(excerpt)
                    }
                }
            }

            if !excerpts.isEmpty {
                matches.append([
                    "filename": file.filename,
                    "title": file.title,
                    "excerpts": excerpts
                ])
            }
        }

        let result: [String: Any] = [
            "query": query,
            "stroke_filter": stroke ?? "",
            "matches_found": matches.count,
            "matches": matches
        ]

        return try encodeJSON(result)
    }

    private func getRelatedTechniques(filename: String?) throws -> String {
        guard let filename else {
            throw ToolError.missingParameter("filename")
        }

        let normalizedFilename = filename.hasSuffix(".md") ? filename : "\(filename).md"

        let content = try contentLoader.loadMarkdown(filename: normalizedFilename)
        let parsed = markdownParser.parse(filename: normalizedFilename, rawContent: content)

        // Build related techniques with previews
        var related: [[String: Any]] = []

        for relatedFile in parsed.relatedTechniques {
            if let relatedContent = try? contentLoader.loadMarkdown(filename: relatedFile) {
                let relatedParsed = markdownParser.parse(filename: relatedFile, rawContent: relatedContent)
                related.append([
                    "filename": relatedFile,
                    "title": relatedParsed.title,
                    "overview_preview": String(relatedParsed.overview.prefix(150))
                ])
            }
        }

        // Also include prev/next navigation
        var navigation: [String: Any?] = [:]
        if let prevFile = parsed.prevFile {
            navigation["prev_file"] = prevFile
        }
        if let nextFile = parsed.nextFile {
            navigation["next_file"] = nextFile
        }

        let result: [String: Any] = [
            "source_file": normalizedFilename,
            "source_title": parsed.title,
            "related_techniques": related,
            "navigation": navigation
        ]

        return try encodeJSON(result)
    }

    // MARK: - Helpers

    private func parseArguments(_ toolCall: ToolCall) throws -> [String: Any] {
        guard let data = toolCall.function.arguments.data(using: .utf8) else {
            throw ToolError.executionError("Could not decode arguments")
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ToolError.executionError("Arguments are not valid JSON")
        }
        return json
    }

    private func encodeJSON(_ value: Any) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted])
        guard let string = String(data: data, encoding: .utf8) else {
            throw ToolError.executionError("Could not encode result as JSON")
        }
        return string
    }
}