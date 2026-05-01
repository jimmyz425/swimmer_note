import Foundation

public struct TechniqueMarkdownParser: Sendable {
    public init() {}
    
    public func parse(filename: String, rawContent: String) -> ParsedTechniqueContent {
        let title = extractTitle(from: rawContent)
        let (overview, difficulty) = extractOverview(from: rawContent)
        let keyPoints = extractKeyPoints(from: rawContent)
        let commonMistakes = extractCommonMistakes(from: rawContent)
        let specificDrills = extractSpecificDrills(from: rawContent)
        let competitiveDrills = extractCompetitiveDrills(from: rawContent)
        let relatedTechniques = extractRelatedTechniques(from: rawContent)
        let techniqueTable = extractTechniqueTable(from: rawContent)
        let (prevFile, nextFile) = extractNavigationLinks(from: rawContent)

        return ParsedTechniqueContent(
            filename: filename,
            title: title,
            overview: overview,
            difficulty: difficulty,
            keyPoints: keyPoints,
            commonMistakes: commonMistakes,
            specificDrills: specificDrills,
            competitiveDrills: competitiveDrills,
            relatedTechniques: relatedTechniques,
            techniqueTable: techniqueTable,
            prevFile: prevFile,
            nextFile: nextFile,
            rawContent: rawContent
        )
    }
    
    private func extractTitle(from content: String) -> String {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        for line in lines {
            if line.hasPrefix("# ") {
                return String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            }
        }
        return ""
    }
    
    private func extractOverview(from content: String) -> (overview: String, difficulty: String) {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        var overviewLines: [String] = []
        var difficulty = ""
        var inOverviewSection = false
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed == "## Overview" {
                inOverviewSection = true
                continue
            }
            
            if inOverviewSection {
                if trimmed.hasPrefix("## ") {
                    break
                }
                
                if trimmed.hasPrefix("**Difficulty") {
                    // Extract difficulty value: "**Difficulty:** value"
                    let afterPrefix = trimmed.dropFirst(12) // Drop "**Difficulty"
                    // Find the value after "**:" or ":**"
                    if let colonIndex = afterPrefix.firstIndex(of: ":") {
                        var value = String(afterPrefix[afterPrefix.index(after: colonIndex)...])
                        // Remove trailing ** if present
                        if value.hasSuffix("**") {
                            value = String(value.dropLast(2))
                        }
                        difficulty = stripMarkdown(value.trimmingCharacters(in: .whitespaces))
                    }
                } else if !trimmed.isEmpty && !trimmed.hasPrefix(">") {
                    overviewLines.append(String(line))
                }
            }
        }
        
        return (stripMarkdown(overviewLines.joined(separator: "\n").trimmingCharacters(in: .whitespaces)), difficulty)
    }
    
    private func extractKeyPoints(from content: String) -> [String] {
        return extractBulletList(from: content, sectionHeader: "## Key Points to Remember")
    }
    
    private func extractCommonMistakes(from content: String) -> [String] {
        return extractBulletList(from: content, sectionHeader: "## Common Mistakes to Avoid")
    }
    
    private func extractBulletList(from content: String, sectionHeader: String) -> [String] {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        var bullets: [String] = []
        var inSection = false
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed == sectionHeader {
                inSection = true
                continue
            }
            
            if inSection {
                if trimmed.hasPrefix("## ") {
                    break
                }
                
                if trimmed.hasPrefix("- ") {
                    let bullet = String(trimmed.dropFirst(2))
                    bullets.append(stripMarkdown(bullet))
                }
            }
        }
        
        return bullets
    }
    
    private func stripMarkdown(_ text: String) -> String {
        var result = text

        // Remove bold markers **text**
        result = result.replacingOccurrences(of: "\\*\\*([^*]+)\\*\\*", with: "$1", options: .regularExpression)

        // Remove any remaining ** pairs
        result = result.replacingOccurrences(of: "**", with: "")

        // Remove italic markers *text* (single asterisk, not part of bold)
        result = result.replacingOccurrences(of: "\\*([^*]+)\\*", with: "$1", options: .regularExpression)

        // Remove wiki-style links [[filename]]
        while let start = result.range(of: "[[") {
            guard let end = result.range(of: "]]", range: start.upperBound..<result.endIndex) else { break }
            let inner = String(result[start.upperBound..<end.lowerBound])
            // Extract just the filename part (remove path prefix if present)
            let filename = inner.hasPrefix("swimming-strokes/")
                ? String(inner.dropFirst("swimming-strokes/".count))
                : inner
            result.replaceSubrange(start.lowerBound..<end.upperBound, with: filename)
        }

        // Remove backticks `code`
        result = result.replacingOccurrences(of: "`([^`]+)`", with: "$1", options: .regularExpression)

        return result.trimmingCharacters(in: .whitespaces)
    }
    
    private func extractSpecificDrills(from content: String) -> [SpecificDrill] {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        var drills: [SpecificDrill] = []
        var inSection = false
        var skipHeaderRow = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Handle standard technique files: "## Specific Drills"
            if trimmed == "## Specific Drills" {
                inSection = true
                skipHeaderRow = true
                continue
            }

            // Handle dry-land training files: sections ending with "Drills"
            if trimmed.hasPrefix("## ") && trimmed.hasSuffix("Drills") && !trimmed.hasSuffix("Competitive Drills") {
                inSection = true
                skipHeaderRow = true
                continue
            }

            if inSection {
                // Stop at next section
                if trimmed.hasPrefix("## ") && !trimmed.hasSuffix("Drills") {
                    inSection = false
                    continue
                }

                // Stop at "---" divider between drill sections
                if trimmed == "---" {
                    inSection = false
                    continue
                }

                if trimmed.hasPrefix("|") && trimmed.hasSuffix("|") {
                    if skipHeaderRow {
                        skipHeaderRow = false
                        continue
                    }

                    // Skip separator row like |-------|-------------|
                    if trimmed.contains("---") {
                        continue
                    }

                    // Parse table row: | **Name** | Description | Focus Points |
                    let parts = trimmed.dropFirst(1).dropLast(1).split(separator: "|")
                    if parts.count >= 2 {
                        let namePart = parts[0].trimmingCharacters(in: .whitespaces)
                        let descPart = parts[1].trimmingCharacters(in: .whitespaces)

                        // Build description from multiple columns if available
                        var fullDesc = stripMarkdown(descPart)
                        if parts.count >= 3 {
                            let focusPart = parts[2].trimmingCharacters(in: .whitespaces)
                            fullDesc += " | Focus: " + stripMarkdown(focusPart)
                        }

                        drills.append(SpecificDrill(
                            name: stripMarkdown(namePart),
                            description: fullDesc
                        ))
                    }
                }
            }
        }

        return drills
    }
    
    private func extractCompetitiveDrills(from content: String) -> [CompetitiveDrill] {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        var drills: [CompetitiveDrill] = []
        var currentDrill: CompetitiveDrillData?
        var tieredTargets: [String: String] = [:]
        var videoChecks: [String] = []
        var inTieredBlock = false
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Start new drill: #### Drill N: Name
            if trimmed.hasPrefix("#### Drill ") {
                // Save previous drill
                if let drillData = currentDrill {
                    drills.append(CompetitiveDrill(
                        name: drillData.name,
                        selfCheck: drillData.selfCheck,
                        tieredTargetsTitle: drillData.tieredTargetsTitle,
                        tieredTargets: drillData.tieredTargets,
                        videoChecks: drillData.videoChecks,
                        competitiveImpact: drillData.competitiveImpact
                    ))
                }
                
                // Parse drill name: "#### Drill 1: Streamline Push-offs (measure distance, not time)"
                let drillLine = trimmed.dropFirst("#### Drill ".count)
                if let colonIndex = drillLine.firstIndex(of: ":") {
                    let name = String(drillLine[drillLine.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                    currentDrill = CompetitiveDrillData(name: stripMarkdown(name))
                } else {
                    currentDrill = CompetitiveDrillData(name: stripMarkdown(String(drillLine)))
                }
                tieredTargets = [:]
                videoChecks = []
                inTieredBlock = false
                continue
            }

            if currentDrill != nil {
                // Self-Check
                if trimmed.hasPrefix("**Self-Check:**") || trimmed.hasPrefix("**Self Check:**") {
                    let check = trimmed.replacingOccurrences(of: "**Self-Check:**", with: "")
                        .replacingOccurrences(of: "**Self Check:**", with: "")
                        .trimmingCharacters(in: .whitespaces)
                    currentDrill?.selfCheck = stripMarkdown(check)
                    continue
                }
                
                // Tiered targets callout block
                if trimmed.hasPrefix("> [!note] Tiered Targets") || trimmed.hasPrefix("> [!tip] Tiered") {
                    // Extract title from parentheses: "Tiered Targets (Title here)"
                    if let parenStart = trimmed.range(of: "("),
                       let parenEnd = trimmed.range(of: ")", range: parenStart.upperBound..<trimmed.endIndex) {
                        let title = String(trimmed[parenStart.upperBound..<parenEnd.lowerBound])
                        currentDrill?.tieredTargetsTitle = stripMarkdown(title)
                    }
                    inTieredBlock = true
                    continue
                }
                
                if inTieredBlock {
                    if trimmed.hasPrefix(">") {
                        let content = String(trimmed.dropFirst(1)).trimmingCharacters(in: .whitespaces)

                        // End of tiered block
                        if content.isEmpty || content.hasPrefix("|") {
                            continue
                        }

                        // Parse tier line: "- **Beginner:** target"
                        if content.hasPrefix("- ") {
                            let tierLine = String(content.dropFirst(2))

                            // Find the colon that separates tier name from target
                            if let colonIndex = tierLine.firstIndex(of: ":") {
                                // Tier name part (may have ** around it)
                                let tierNamePartRaw = String(tierLine[..<colonIndex])
                                // Target part (after colon)
                                let targetPart = String(tierLine[tierLine.index(after: colonIndex)...])

                                // Clean up tier name: strip all markdown
                                let tierName = stripMarkdown(tierNamePartRaw)

                                // Clean up target: strip all markdown
                                let target = stripMarkdown(targetPart)

                                tieredTargets[tierName] = target
                                currentDrill?.tieredTargets[tierName] = target
                            }
                        }
                    } else if !trimmed.isEmpty && !trimmed.hasPrefix(">") {
                        inTieredBlock = false
                    }
                }
                
                // Video Check
                if trimmed.hasPrefix("**Video Check") {
                    continue // Skip header
                }
                if trimmed.hasPrefix("- ") && currentDrill?.competitiveImpact.isEmpty == true && !inTieredBlock {
                    // Could be video check or competitive impact content
                    let content = stripMarkdown(String(trimmed.dropFirst(2)))
                    videoChecks.append(content)
                }
                
                // Competitive Impact
                if trimmed.hasPrefix("**Competitive Impact:**") || trimmed.hasPrefix("**Competitive Impact:**") {
                    let impact = trimmed.replacingOccurrences(of: "**Competitive Impact:**", with: "")
                        .replacingOccurrences(of: "**Competitive impact:**", with: "")
                        .trimmingCharacters(in: .whitespaces)
                    currentDrill?.competitiveImpact = stripMarkdown(impact)
                    continue
                }
            }
        }
        
        // Save last drill
        if let drillData = currentDrill {
            drills.append(CompetitiveDrill(
                name: drillData.name,
                selfCheck: drillData.selfCheck,
                tieredTargetsTitle: drillData.tieredTargetsTitle,
                tieredTargets: drillData.tieredTargets,
                videoChecks: drillData.videoChecks,
                competitiveImpact: drillData.competitiveImpact
            ))
        }
        
        return drills
    }
    
    private func extractRelatedTechniques(from content: String) -> [String] {
        var techniques: [String] = []

        // Extract from ## Related Techniques section
        techniques.append(contentsOf: extractFromRelatedSection(content))

        // Extract from ## Technique Files table (main stroke files)
        techniques.append(contentsOf: extractFromTechniqueFilesTable(content))

        // Extract from ## Dry Land Training link
        techniques.append(contentsOf: extractDryLandLink(content))

        return techniques
    }

    private func extractFromRelatedSection(_ content: String) -> [String] {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        var techniques: [String] = []
        var inSection = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed == "## Related Techniques" {
                inSection = true
                continue
            }

            if inSection {
                if trimmed.hasPrefix("## ") || trimmed.isEmpty {
                    break
                }

                if trimmed.hasPrefix("- ") {
                    let content = String(trimmed.dropFirst(2))
                    techniques.append(contentsOf: extractWikiLinks(from: content))
                }
            }
        }

        return techniques
    }

    private func extractFromTechniqueFilesTable(_ content: String) -> [String] {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        var techniques: [String] = []
        var inTable = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed == "## Technique Files" {
                inTable = true
                continue
            }

            if inTable {
                // Stop at next section
                if trimmed.hasPrefix("## ") {
                    break
                }

                // Skip table header and separator
                if trimmed.hasPrefix("| #") || trimmed.hasPrefix("| ---") {
                    continue
                }

                // Extract wiki links from table rows
                if trimmed.hasPrefix("|") {
                    techniques.append(contentsOf: extractWikiLinks(from: trimmed))
                }
            }
        }

        return techniques
    }

    private func extractDryLandLink(_ content: String) -> [String] {
        // Look for dry-land training link in ## Dry Land Training section
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        var inSection = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed == "## Dry Land Training" {
                inSection = true
                continue
            }

            if inSection {
                if trimmed.hasPrefix("## ") || trimmed.isEmpty {
                    break
                }

                let links = extractWikiLinks(from: trimmed)
                for link in links {
                    if link.contains("dry-land") || link.contains("dryland") {
                        return [link]
                    }
                }
            }
        }

        return []
    }

    private func extractWikiLinks(from text: String) -> [String] {
        var links: [String] = []
        var remaining = text

        while let startRange = remaining.range(of: "[["),
              let endRange = remaining.range(of: "]]", range: startRange.upperBound..<remaining.endIndex) {
            let link = String(remaining[startRange.upperBound..<endRange.lowerBound])

            // Remove "swimming-strokes/" prefix if present
            let filename = link.hasPrefix("swimming-strokes/")
                ? String(link.dropFirst("swimming-strokes/".count))
                : link

            links.append(filename)

            // Continue searching for more links
            remaining = String(remaining[endRange.upperBound...])
        }

        return links
    }
    
    private func extractNavigationLinks(from content: String) -> (prev: String?, next: String?) {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        var prevFile: String?
        var nextFile: String?

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("> ← Prev:") {
                // Extract prev link from [[filename]]
                if let startRange = trimmed.range(of: "[["),
                   let endRange = trimmed.range(of: "]]") {
                    let link = String(trimmed[startRange.upperBound..<endRange.lowerBound])
                    prevFile = link.hasPrefix("swimming-strokes/")
                        ? String(link.dropFirst("swimming-strokes/".count))
                        : link
                }
            }

            if trimmed.contains("Next: [[") {
                if let startRange = trimmed.range(of: "[["),
                   let endRange = trimmed.range(of: "]]") {
                    let link = String(trimmed[startRange.upperBound..<endRange.lowerBound])
                    nextFile = link.hasPrefix("swimming-strokes/")
                        ? String(link.dropFirst("swimming-strokes/".count))
                        : link
                }
            }

            // Stop after overview section starts
            if trimmed == "---" {
                break
            }
        }

        return (prevFile, nextFile)
    }

    /// Extract technique table from main stroke files (numbered 1-9 with difficulty)
    /// Format: | # | Technique | Difficulty | Key Focus | File |
    private func extractTechniqueTable(from content: String) -> [TechniqueTableEntry] {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        var entries: [TechniqueTableEntry] = []
        var inTable = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed == "## Technique Files" {
                inTable = true
                continue
            }

            if inTable {
                // Stop at next section
                if trimmed.hasPrefix("## ") {
                    break
                }

                // Skip table header and separator lines
                if trimmed.hasPrefix("| #") || trimmed.hasPrefix("| ---") || trimmed.isEmpty {
                    continue
                }

                // Parse table row: | 1 | Body Position | Easiest | Foundation | [[file]] |
                if trimmed.hasPrefix("|") {
                    let parts = trimmed.split(separator: "|", omittingEmptySubsequences: true)
                    if parts.count >= 5 {
                        // Column 0: number, Column 1: name, Column 2: difficulty, Column 3: focus, Column 4: file link
                        let numberStr = parts[0].trimmingCharacters(in: .whitespaces)
                        let name = stripMarkdown(parts[1].trimmingCharacters(in: .whitespaces))
                        let difficulty = stripMarkdown(parts[2].trimmingCharacters(in: .whitespaces))
                        let keyFocus = stripMarkdown(parts[3].trimmingCharacters(in: .whitespaces))
                        let fileCell = parts[4].trimmingCharacters(in: .whitespaces)

                        // Parse number (may have asterisk footnote markers)
                        let number = Int(numberStr.filter { $0.isNumber }) ?? 0

                        // Extract filename from wiki link [[swimming-strokes/filename]]
                        let filename: String
                        if let startRange = fileCell.range(of: "[["),
                           let endRange = fileCell.range(of: "]]") {
                            let link = String(fileCell[startRange.upperBound..<endRange.lowerBound])
                            filename = link.hasPrefix("swimming-strokes/")
                                ? String(link.dropFirst("swimming-strokes/".count))
                                : link
                        } else {
                            filename = fileCell
                        }

                        if number > 0 && !name.isEmpty {
                            entries.append(TechniqueTableEntry(
                                number: number,
                                name: name,
                                difficulty: difficulty,
                                keyFocus: keyFocus,
                                filename: filename
                            ))
                        }
                    }
                }
            }
        }

        return entries
    }
}

private struct CompetitiveDrillData {
    var name: String
    var selfCheck: String = ""
    var tieredTargetsTitle: String = ""
    var tieredTargets: [String: String] = [:]
    var videoChecks: [String] = []
    var competitiveImpact: String = ""
}
