import Foundation

extension CombinedToolExecutor {
    // MARK: - Resources Navigation Tools

    func listTechniqueFiles(stroke: String?) throws -> String {
        let allFiles = try contentLoader.listTechniqueMarkdownFiles()

        let filteredFiles: [TechniqueFileInfo]
        if let stroke {
            filteredFiles = allFiles.filter { $0.stroke == stroke }
        } else {
            filteredFiles = allFiles
        }

        // Concise format - just filename and title
        let result = filteredFiles.map { file -> [String: String] in
            [
                "filename": file.filename,
                "stroke": file.stroke,
                "title": file.title
            ]
        }

        return try encodeJSON(result)
    }

    func readTechniqueFile(filename: String?) throws -> String {
        guard let filename else {
            throw ToolError.missingParameter("filename")
        }

        let normalizedFilename = filename.hasSuffix(".md") ? filename : "\(filename).md"

        let content = try contentLoader.loadMarkdown(filename: normalizedFilename)
        let parsed = markdownParser.parse(filename: normalizedFilename, rawContent: content)

        // Combine drills into a simple format
        var allDrills: [[String: Any]] = []

        // Specific drills
        for drill in parsed.specificDrills {
            allDrills.append([
                "name": drill.name,
                "type": "specific",
                "description": String(drill.description.prefix(100))
            ])
        }

        // Competitive metrics with tiered targets
        for metric in parsed.competitiveMetrics {
            allDrills.append([
                "name": metric.name,
                "type": "competitive",
                "targets": metric.tieredTargets
            ])
        }

        // Build result with navigation links
        var result: [String: Any] = [
            "filename": normalizedFilename,
            "title": parsed.title,
            "difficulty": parsed.difficulty,
            "overview": String(parsed.overview.prefix(200)),
            "key_points": parsed.keyPoints.map { String($0.prefix(80)) },
            "drills": allDrills,
            "related_files": parsed.relatedTechniques
        ]

        // Include technique table for main stroke files (difficulty-ranked progression)
        if !parsed.techniqueTable.isEmpty {
            result["technique_table"] = parsed.techniqueTable.map { entry in
                [
                    "number": entry.number,
                    "name": entry.name,
                    "difficulty": entry.difficulty,
                    "key_focus": String(entry.keyFocus.prefix(50)),
                    "filename": entry.filename
                ]
            }
            result["note"] = "Technique number = difficulty ranking (1=Easiest, 9=Hard). Pick technique matching swimmer's skill level."
        }

        // Add prev/next navigation if available
        if let prev = parsed.prevFile {
            result["prev_file"] = prev
        }
        if let next = parsed.nextFile {
            result["next_file"] = next
        }

        return try encodeJSON(result)
    }

    func getTechniqueDrills(filename: String?) throws -> String {
        guard let filename else {
            throw ToolError.missingParameter("filename")
        }

        let normalizedFilename = filename.hasSuffix(".md") ? filename : "\(filename).md"

        let content = try contentLoader.loadMarkdown(filename: normalizedFilename)
        let parsed = markdownParser.parse(filename: normalizedFilename, rawContent: content)

        var result: [String: Any] = [
            "filename": normalizedFilename,
            "title": parsed.title,
            "difficulty": parsed.difficulty
        ]

        // Specific drills
        if !parsed.specificDrills.isEmpty {
            result["specific_drills"] = parsed.specificDrills.map { drill in
                [
                    "name": drill.name,
                    "description": drill.description
                ]
            }
        }

        // Competitive drills with tiered targets
        if !parsed.competitiveMetrics.isEmpty {
            result["competitive_drills"] = parsed.competitiveMetrics.map { metric in
                var entry: [String: Any] = [
                    "name": metric.name,
                    "self_check": metric.selfCheck
                ]
                if !metric.tieredTargets.isEmpty {
                    entry["tiered_targets"] = metric.tieredTargets
                }
                if !metric.videoChecks.isEmpty {
                    entry["video_checks"] = metric.videoChecks
                }
                return entry
            }
        }

        if parsed.specificDrills.isEmpty && parsed.competitiveMetrics.isEmpty {
            result["note"] = "No drills defined for this technique"
        }

        return try encodeJSON(result)
    }

    func searchContent(query: String?, stroke: String?) throws -> String {
        guard let query else {
            throw ToolError.missingParameter("query")
        }

        let allFiles = try contentLoader.listTechniqueMarkdownFiles()
        let searchTerms = query.lowercased().split(separator: " ").map(String.init)

        let filteredFiles = allFiles.filter { stroke == nil || $0.stroke == stroke }

        var matches: [[String: Any]] = []

        for file in filteredFiles {
            let content = try contentLoader.loadMarkdown(filename: file.filename)
            let parsed = markdownParser.parse(filename: file.filename, rawContent: content)

            // Search within structured fields instead of raw text
            var matchedSections: [String: Any] = [:]
            let titleLower = parsed.title.lowercased()
            let titleMatch = searchTerms.contains(where: { term in titleLower.contains(term) })
            if titleMatch {
                matchedSections["title"] = parsed.title
            }

            let keyPointMatches = parsed.keyPoints.compactMap { kp -> String? in
                let kpLower = kp.lowercased()
                if searchTerms.contains(where: { term in kpLower.contains(term) }) {
                    return String(kp.prefix(100))
                }
                return nil
            }
            if !keyPointMatches.isEmpty {
                matchedSections["key_points"] = keyPointMatches
            }

            let drillMatches = parsed.specificDrills.compactMap { drill -> [String: Any]? in
                let combined = (drill.name + " " + drill.description).lowercased()
                if searchTerms.contains(where: { term in combined.contains(term) }) {
                    return [
                        "name": drill.name,
                        "description": String(drill.description.prefix(100))
                    ]
                }
                return nil
            }
            if !drillMatches.isEmpty {
                matchedSections["drills"] = drillMatches
            }

            let metricMatches = parsed.competitiveMetrics.compactMap { metric -> [String: Any]? in
                let combined = (metric.name + " " + metric.selfCheck).lowercased()
                if searchTerms.contains(where: { term in combined.contains(term) }) {
                    var entry: [String: Any] = ["name": metric.name]
                    if !metric.tieredTargets.isEmpty {
                        entry["tiered_targets"] = metric.tieredTargets
                    }
                    return entry
                }
                return nil
            }
            if !metricMatches.isEmpty {
                matchedSections["competitive_drills"] = metricMatches
            }

            if !matchedSections.isEmpty {
                var matchEntry: [String: Any] = [
                    "filename": file.filename,
                    "title": parsed.title,
                    "difficulty": parsed.difficulty,
                    "matched_sections": matchedSections
                ]
                if let prev = parsed.prevFile {
                    matchEntry["prev_file"] = prev
                }
                if let next = parsed.nextFile {
                    matchEntry["next_file"] = next
                }
                matches.append(matchEntry)
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

    func getRelatedTechniques(filename: String?) throws -> String {
        guard let filename else {
            throw ToolError.missingParameter("filename")
        }

        let normalizedFilename = filename.hasSuffix(".md") ? filename : "\(filename).md"

        let content = try contentLoader.loadMarkdown(filename: normalizedFilename)
        let parsed = markdownParser.parse(filename: normalizedFilename, rawContent: content)

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
}
