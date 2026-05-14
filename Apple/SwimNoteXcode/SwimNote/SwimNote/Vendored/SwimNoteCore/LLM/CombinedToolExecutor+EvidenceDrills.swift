import Foundation

extension CombinedToolExecutor {
    // MARK: - Evidence-Based Drills Tool

    func readEvidenceDrills(stroke: String?, drill: String?) throws -> String {
        guard let stroke else {
            throw ToolError.missingParameter("stroke")
        }

        let validStrokes = ["freestyle", "backstroke", "breaststroke", "butterfly", "all"]
        guard validStrokes.contains(stroke.lowercased()) else {
            throw ToolError.invalidParameter("stroke", stroke)
        }

        // Load the evidence-based drills document
        let filename = "stroke-evidence-based-drills.md"

        // Try to find the file in bundle
        guard let url = Bundle.main.url(forResource: "stroke-evidence-based-drills", withExtension: "md", subdirectory: "swimming-strokes") ??
                        Bundle.main.url(forResource: "stroke-evidence-based-drills", withExtension: "md", subdirectory: "Resources/swimming-strokes") ??
                        Bundle.main.url(forResource: "stroke-evidence-based-drills", withExtension: "md") else {
            throw ToolError.executionError("Could not find \(filename)")
        }

        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            throw ToolError.executionError("Could not read \(filename)")
        }

        // "all" returns just the quick reference index
        if stroke.lowercased() == "all" {
            let indexContent = extractEvidenceDrillIndex(content: content)
            return try encodeJSON([
                "scope": "all_strokes",
                "note": "This is the quick reference. Call with stroke='freestyle' (etc.) for full drill details, or stroke='freestyle' + drill='F1' for a specific drill.",
                "drill_index": indexContent
            ])
        }

        // Specific stroke requested
        if let drillCode = drill, !drillCode.isEmpty {
            // Return a specific drill
            let drillContent = extractEvidenceDrill(content: content, stroke: stroke.lowercased(), drill: drillCode)
            return try encodeJSON([
                "stroke": stroke,
                "drill": drillCode,
                "content": drillContent
            ])
        } else {
            // Return all drills for this stroke
            let drillsContent = extractEvidenceDrillsForStroke(content: content, stroke: stroke.lowercased())
            return try encodeJSON([
                "stroke": stroke,
                "drills_count": drillsContent.count,
                "drills": drillsContent,
                "note": "Each drill entry has code, name, evidence, distance, equipment, and when_to_use. Call with drill='F1' (etc.) for full set details."
            ])
        }
    }

    /// Extract the quick reference index (compact table) for "all" requests
    func extractEvidenceDrillIndex(content: String) -> String {
        // Extract from "## Drill Quick Reference" to the next major section
        guard let start = content.range(of: "## Drill Quick Reference — LLM Index") else {
            return "Drill index not found"
        }
        guard let end = content[start.lowerBound...].range(of: "\n## Freestyle Drills") else {
            return String(content[start.lowerBound...].prefix(2000))
        }
        return String(content[start.lowerBound..<end.lowerBound])
    }

    /// Extract all drills for a specific stroke
    func extractEvidenceDrillsForStroke(content: String, stroke: String) -> [[String: String]] {
        let strokeHeaders: [String: String] = [
            "freestyle": "## Freestyle Drills",
            "backstroke": "## Backstroke Drills",
            "breaststroke": "## Breaststroke Drills",
            "butterfly": "## Butterfly Drills"
        ]

        guard let header = strokeHeaders[stroke] else { return [] }

        guard let sectionStart = content.range(of: header) else { return [] }

        // Find the end of this stroke section (next major stroke section or "## Quick Reference")
        let sectionContent = String(content[sectionStart.lowerBound...])
        let nextSectionPatterns = ["## Backstroke Drills", "## Breaststroke Drills", "## Butterfly Drills", "## Quick Reference: All Drills"]

        var minOffset: Int? = nil
        for pattern in nextSectionPatterns {
            if let range = sectionContent.range(of: pattern) {
                let offset = sectionContent.distance(from: sectionContent.startIndex, to: range.lowerBound)
                if minOffset == nil || offset < minOffset! {
                    minOffset = offset
                }
            }
        }

        let endPosition: String.Index
        if let offset = minOffset {
            endPosition = content.index(sectionStart.lowerBound, offsetBy: offset)
        } else {
            endPosition = content.endIndex
        }

        let sectionText = String(content[sectionStart.lowerBound..<endPosition])

        // Parse individual drills: "### Drill F1: ..."
        var drills: [[String: String]] = []
        let lines = sectionText.split(separator: "\n", omittingEmptySubsequences: false)

        var currentDrill: [String: String]?
        var evidence: String?

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("### Drill ") {
                // Save previous drill
                if let drill = currentDrill {
                    drills.append(drill)
                }

                // Parse drill code and name: "### Drill F1: Tempo Ladder (Progressive Stroke Rate Build)"
                let drillPart = String(trimmed.dropFirst(9)) // after "### Drill "
                if let colonRange = drillPart.firstIndex(of: ":") {
                    let code = String(drillPart[..<colonRange]).trimmingCharacters(in: .whitespaces)
                    let name = String(drillPart[drillPart.index(after: colonRange)...]).trimmingCharacters(in: .whitespaces)
                    currentDrill = ["code": code, "name": name]
                }
            } else if trimmed.hasPrefix("**Evidence:**") {
                evidence = String(trimmed.dropFirst(11)).trimmingCharacters(in: .whitespaces)
                currentDrill?["evidence"] = evidence
            } else if trimmed.hasPrefix("**Base:**") {
                let base = String(trimmed.dropFirst(8)).trimmingCharacters(in: .whitespaces)
                currentDrill?["base"] = base
            }
        }

        // Don't forget the last drill
        if let drill = currentDrill {
            drills.append(drill)
        }

        return drills
    }

    /// Extract full details of a specific drill
    func extractEvidenceDrill(content: String, stroke: String, drill: String) -> String {
        let strokeHeaders: [String: String] = [
            "freestyle": "## Freestyle Drills",
            "backstroke": "## Backstroke Drills",
            "breaststroke": "## Breaststroke Drills",
            "butterfly": "## Butterfly Drills"
        ]

        guard let header = strokeHeaders[stroke] else { return "Stroke not found: \(stroke)" }
        guard let sectionStart = content.range(of: header) else { return "Stroke section not found" }

        // Find the specific drill
        let drillMarker = "### Drill \(drill):"
        guard let drillStart = String(content[sectionStart.lowerBound...]).range(of: drillMarker) else {
            return "Drill \(drill) not found in \(stroke). Available: search for '### Drill X:' patterns."
        }

        let drillOffset = content.distance(from: sectionStart.lowerBound, to: drillStart.lowerBound)
        let absoluteDrillStart = content.index(sectionStart.lowerBound, offsetBy: drillOffset)

        // Find the end of this drill (next "### Drill" or next major section)
        let remainingContent = String(content[absoluteDrillStart...])
        let endPatterns = ["\n### Drill ", "\n## "]

        var minOffset: Int? = nil
        for pattern in endPatterns {
            if let range = remainingContent.range(of: pattern) {
                let offset = remainingContent.distance(from: remainingContent.startIndex, to: range.lowerBound)
                if minOffset == nil || offset < minOffset! {
                    minOffset = offset
                }
            }
        }

        let endPosition: String.Index
        if let offset = minOffset {
            endPosition = content.index(absoluteDrillStart, offsetBy: offset)
        } else {
            endPosition = content.endIndex
        }

        return String(content[absoluteDrillStart..<endPosition])
    }
}
