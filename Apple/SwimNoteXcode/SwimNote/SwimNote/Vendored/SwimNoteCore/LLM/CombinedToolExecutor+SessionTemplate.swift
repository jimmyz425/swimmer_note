import Foundation

extension CombinedToolExecutor {
    // MARK: - Session Template Document

    func readSessionTemplate(section: String?) throws -> String {
        let sectionParam = section ?? "all"

        let filename = "swimming-session-template.md"
        let content = try contentLoader.loadMarkdown(filename: filename)

        if sectionParam == "all" {
            let slots = extractSessionSection(content: content, sectionMarker: "## Slot Reference")
            let options = extractSessionSection(content: content, sectionMarker: "## Option Catalog")
            let scaling = extractSessionSection(content: content, sectionMarker: "## Tier Distance Scaling")

            let result: [String: Any] = [
                "document": "swimming-session-template",
                "section": "all",
                "slots": String(slots.prefix(800)),
                "options": String(options.prefix(800)),
                "scaling": String(scaling.prefix(800)),
                "note": "Each section is truncated. Call with section='slots', 'options', or 'scaling' for full detail on one area."
            ]
            return try encodeJSON(result)
        }

        let sectionContent = extractSessionSectionByParam(content: content, section: sectionParam)

        let result: [String: Any] = [
            "document": "swimming-session-template",
            "section_requested": sectionParam,
            "content": String(sectionContent.prefix(2000))
        ]

        return try encodeJSON(result)
    }

    func extractSessionSection(content: String, sectionMarker: String) -> String {
        guard let sectionStart = content.range(of: sectionMarker) else {
            return "Section not found"
        }

        let remainingContent = String(content[sectionStart.lowerBound...])
        let nextSectionPattern = "\n## "

        if let nextSectionRange = remainingContent.range(of: nextSectionPattern, options: .regularExpression) {
            return String(remainingContent[..<nextSectionRange.lowerBound])
        } else {
            return String(remainingContent.prefix(2000))
        }
    }

    func extractSessionSectionByParam(content: String, section: String) -> String {
        let sectionMarkers: [String: String] = [
            "slots": "## Slot Reference",
            "options": "## Option Catalog",
            "scaling": "## Tier Distance Scaling"
        ]

        guard let marker = sectionMarkers[section] else {
            return "Section not found. Available sections: slots, options, scaling, all"
        }

        return extractSessionSection(content: content, sectionMarker: marker)
    }
}
