import Foundation

extension CombinedToolExecutor {
    // MARK: - USA Swimming Structure Document

    func readUSASwimmingStructure(section: String?) throws -> String {
        let sectionParam = section ?? "all"

        // Load the USA Swimming structure document
        let filename = "club-training-reference.md"
        let content = try contentLoader.loadMarkdown(filename: filename)

        // If requesting all, return a structured summary with key sections
        if sectionParam == "all" {
            // Extract key sections for Phase 1 context
            let summaryTable = extractUSASwimmingSection(content: content, sectionMarker: "## Quick-Reference Summary Table")
            let zoneDistribution = extractUSASwimmingSection(content: content, sectionMarker: "## Training Zone Distribution Summary by Group")
            let volumeProgression = extractUSASwimmingSection(content: content, sectionMarker: "## Volume Progression by Group")

            let result: [String: Any] = [
                "document": "club-training-reference",
                "section": "all",
                "summary_table": summaryTable,
                "zone_distribution_summary": zoneDistribution,
                "volume_progression": volumeProgression,
                "note": "Full document has detailed sub-tier breakdowns, time standards, and coaching philosophy. Call with specific section (subtiers, zones, standards) for focused content."
            ]
            return try encodeJSON(result)
        }

        // Extract specific section based on parameter
        let sectionContent = extractUSASwimmingSectionByParam(content: content, section: sectionParam)

        let result: [String: Any] = [
            "document": "club-training-reference",
            "section_requested": sectionParam,
            "content": sectionContent
        ]

        return try encodeJSON(result)
    }

    func extractUSASwimmingSection(content: String, sectionMarker: String) -> String {
        // Find the section start
        guard let sectionStart = content.range(of: sectionMarker) else {
            return "Section not found"
        }

        // Find the next major section (## ) to determine end
        let remainingContent = String(content[sectionStart.lowerBound...])
        let nextSectionPattern = "\n## "

        if let nextSectionRange = remainingContent.range(of: nextSectionPattern, options: .regularExpression) {
            let sectionContent = String(remainingContent[..<nextSectionRange.lowerBound])
            // Cap at 1500 chars for reasonable context
            return String(sectionContent.prefix(1500))
        } else {
            // Last section - return remaining content (capped)
            return String(remainingContent.prefix(1500))
        }
    }

    func extractUSASwimmingSectionByParam(content: String, section: String) -> String {
        let sectionMarkers: [String: String] = [
            "summary": "## Quick-Reference Summary Table",
            "subtiers": "## Sub-Tier Breakdowns",
            "zones": "## Training Zone Distribution Summary by Group",
            "standards": "## Age-Group Time Standards (SCY"
        ]

        guard let marker = sectionMarkers[section] else {
            return "Section not found. Available sections: summary, subtiers, zones, standards, all"
        }

        return extractUSASwimmingSection(content: content, sectionMarker: marker)
    }
}
