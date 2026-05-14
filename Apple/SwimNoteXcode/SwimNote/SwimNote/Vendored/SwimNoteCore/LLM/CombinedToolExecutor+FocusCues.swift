import Foundation

extension CombinedToolExecutor {
    // MARK: - External Focus Cues Tool

    func getExternalFocusCues(stroke: String?, issue: String?) throws -> String {
        guard let stroke else {
            throw ToolError.missingParameter("stroke")
        }

        let validStrokes = ["freestyle", "backstroke", "breaststroke", "butterfly", "starts", "turns"]
        guard validStrokes.contains(stroke.lowercased()) else {
            throw ToolError.invalidParameter("stroke", stroke)
        }

        // Load the external focus cues file
        let filename = "swimming_external_focus_cues_8yo.md"
        let content = try contentLoader.loadMarkdown(filename: filename)

        // If no specific issue, return the full stroke section
        if issue == nil || issue?.isEmpty == true {
            let sectionContent = extractFocusCuesSection(content: content, stroke: stroke.lowercased())
            let result: [String: Any] = [
                "stroke": stroke,
                "issues": sectionContent
            ]
            return try encodeJSON(result)
        }

        // If specific issue, find and return matching cues
        let result = findFocusCuesForIssue(content: content, stroke: stroke.lowercased(), issue: issue!)
        return try encodeJSON(result)
    }

    func extractFocusCuesSection(content: String, stroke: String) -> [[String: Any]] {
        let sectionHeaders: [String: String] = [
            "freestyle": "## Freestyle",
            "backstroke": "## Backstroke",
            "breaststroke": "## Breaststroke",
            "butterfly": "## Butterfly",
            "starts": "## Starts",
            "turns": "## Turns"
        ]

        guard let header = sectionHeaders[stroke] else { return [] }

        // Find section start
        guard let sectionStart = content.range(of: header) else { return [] }
        let afterStart = content[sectionStart.upperBound...]

        // Find next major section (## ) or end of file
        var sectionText: String
        if let nextSection = afterStart.range(of: "\n## ", options: .regularExpression) {
            sectionText = String(afterStart[..<nextSection.lowerBound])
        } else {
            sectionText = String(afterStart)
        }

        // Parse issues and their cues
        var issues: [[String: Any]] = []
        let lines = sectionText.split(separator: "\n", omittingEmptySubsequences: false)

        var currentIssue: String?
        var currentCues: [[String: String]] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Issue header: ### Issue Name
            if trimmed.hasPrefix("### ") {
                // Save previous issue
                if let issue = currentIssue, !currentCues.isEmpty {
                    issues.append(["issue": issue, "cues": currentCues])
                }
                currentIssue = String(trimmed.dropFirst(4))
                currentCues = []
                continue
            }

            // Table row: | N | Cue text | Type |
            if trimmed.hasPrefix("|") && trimmed.contains("|") {
                let parts = trimmed.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                if parts.count >= 3, let number = Int(parts[0]), number > 0 {
                    currentCues.append([
                        "cue": parts[1],
                        "type": parts[2]
                    ])
                }
            }
        }

        // Save last issue
        if let issue = currentIssue, !currentCues.isEmpty {
            issues.append(["issue": issue, "cues": currentCues])
        }

        return issues
    }

    func findFocusCuesForIssue(content: String, stroke: String, issue: String) -> [String: Any] {
        let issues = extractFocusCuesSection(content: content, stroke: stroke)
        let searchTerm = issue.lowercased()

        // Try exact match first, then partial match
        if let exactMatch = issues.first(where: {
            $0["issue"] as? String == searchTerm
        }) {
            return ["stroke": stroke, "issue": issue, "cues": exactMatch["cues"]!]
        }

        if let partialMatch = issues.first(where: {
            ($0["issue"] as? String ?? "").lowercased().contains(searchTerm)
        }) {
            return ["stroke": stroke, "issue": partialMatch["issue"] as! String, "cues": partialMatch["cues"]!]
        }

        // No match found - return available issues for this stroke
        let availableIssues = issues.compactMap { $0["issue"] as? String }
        return [
            "stroke": stroke,
            "issue_searched": issue,
            "error": "No matching issue found",
            "available_issues": availableIssues
        ]
    }
}
