import Foundation

extension CombinedToolExecutor {
    func extractSection(content: String, section: String) -> String {
        // Find section markers in the document
        let sectionMarkers: [String: String] = [
            "zones": "## 2. Training Zones by Purpose",
            "intervals": "## 3. Interval Calculation Methods",
            "periodization": "## 4. Periodization and Interval Selection",
            "events": "## 5. Event-Specific Considerations",
            "levels": "## 6. Swimmer Level Adjustments"
        ]

        guard let marker = sectionMarkers[section] else {
            return "Section not found. Available sections: zones, intervals, periodization, events, levels"
        }

        // Find the section start
        guard let sectionStart = content.range(of: marker) else {
            return "Section content not found in document"
        }

        // Find the next major section (## number) to determine end
        let remainingContent = String(content[sectionStart.lowerBound...])
        let nextSectionPattern = "\n## [0-9]+."

        if let nextSectionRange = remainingContent.range(of: nextSectionPattern, options: .regularExpression) {
            let sectionContent = String(remainingContent[..<nextSectionRange.lowerBound])
            // Cap at 2000 chars for reasonable context
            return String(sectionContent.prefix(2000))
        } else {
            // Last section - return remaining content (capped)
            return String(remainingContent.prefix(2000))
        }
    }
}
