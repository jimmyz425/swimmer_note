import Foundation

// MARK: - Coaching style option

public struct CoachingStyleOption: Identifiable, Hashable, Sendable, Codable {
    /// Stable id, e.g. `silver-a-salo`
    public let id: String
    public let tier: TrainingTier
    public let optionLetter: String
    public let styleName: String
    public let source: String
    public let whenToUse: String

    public var isDefaultRecommendation: Bool {
        whenToUse.localizedCaseInsensitiveContains("default")
    }

    public init(
        id: String,
        tier: TrainingTier,
        optionLetter: String,
        styleName: String,
        source: String,
        whenToUse: String
    ) {
        self.id = id
        self.tier = tier
        self.optionLetter = optionLetter
        self.styleName = styleName
        self.source = source
        self.whenToUse = whenToUse
    }
}

// MARK: - Catalog

public enum CoachingStyleCatalog {
    private static let filename = "swimming-coach-role-reference"
    private static let lock = NSLock()
    private static var cachedOptions: [CoachingStyleOption]?
    private static var cachedContent: String?

    public static func loadContent() -> String? {
        lock.lock()
        defer { lock.unlock() }
        if let cachedContent { return cachedContent }
        guard let url = bundleURL() else { return nil }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        cachedContent = text
        return text
    }

    public static func allOptions() -> [CoachingStyleOption] {
        lock.lock()
        defer { lock.unlock() }
        if let cachedOptions { return cachedOptions }
        let parsed: [CoachingStyleOption]
        if let content = loadContentUnlocked() {
            parsed = parseOptions(from: content)
        } else {
            parsed = fallbackOptions()
        }
        cachedOptions = parsed
        return parsed
    }

    public static func options(for tiers: [TrainingTier]) -> [CoachingStyleOption] {
        let tierSet = Set(tiers)
        return allOptions().filter { tierSet.contains($0.tier) }
    }

    /// Style options for the planner UI — filtered to the profile's TrainingTier only.
    public static func optionsForStylePicker(profile: UserProfile?) -> [CoachingStyleOption] {
        guard let profile else { return allOptions().filter { $0.tier == .silver } }
        return allOptions().filter { $0.tier == profile.trainingTier }
    }

    /// Options for the single tier the profile belongs to.
    public static func optionsGroupedForStylePicker(
        profile: UserProfile?
    ) -> [(tier: TrainingTier, options: [CoachingStyleOption])] {
        guard let profile else {
            let silverOptions = allOptions().filter { $0.tier == .silver }
            guard silverOptions.isEmpty else { return [(.silver, silverOptions)] }
            return []
        }
        let tierOptions = allOptions().filter { $0.tier == profile.trainingTier }
        guard !tierOptions.isEmpty else { return [] }
        return [(profile.trainingTier, tierOptions)]
    }

    public static func defaultSelectionIDs(for tiers: [TrainingTier]) -> Set<String> {
        let available = options(for: tiers)
        let defaults = available.filter(\.isDefaultRecommendation).map(\.id)
        if !defaults.isEmpty { return Set(defaults) }
        return Set(available.prefix(2).map(\.id))
    }

    public static func defaultSelectionIDs(forProfile profile: UserProfile?) -> Set<String> {
        guard let profile else { return defaultSelectionIDs(for: [.silver]) }
        return defaultSelectionIDs(for: [profile.trainingTier])
    }

    /// Drop selections that are not valid for the current profile's TrainingTier.
    public static func pruneSelection(_ selected: Set<String>, profile: UserProfile?) -> Set<String> {
        let allowed = Set(optionsForStylePicker(profile: profile).map(\.id))
        return selected.intersection(allowed)
    }

    /// Migrate old-style IDs (yb-*, yd-*, na-*, int-*, adv-*, elt-*) to new TrainingTier IDs.
    public static func migrateSelectionIDs(_ ids: Set<String>) -> Set<String> {
        let migrationMap: [String: String] = [
            // Youth Beginner -> Pre-Competitive
            "yb-a-playful-learning": "pre_competitive-a-playful-learning",
            "yb-b-differential-learning": "pre_competitive-b-differential-learning",
            "yb-c-ltad-fundamentals": "pre_competitive-c-ltad-fundamentals",
            "yb-d-sakamoto": "pre_competitive-d-sakamoto",
            // Youth Developing -> Bronze
            "yd-a-differential-learning": "bronze-a-differential-learning",
            "yd-b-mckeever": "bronze-b-mckeever",
            "yd-c-ltad-learn-to-train": "bronze-c-ltad-learn-to-train",
            "yd-d-reese": "bronze-d-reese",
            "yd-e-touretski": "silver-e-touretski",
            // Novice Adult -> Bronze / Silver
            "na-a-reese": "bronze-a-reese",
            "na-b-mckeever": "bronze-b-mckeever",
            "na-c-counsilman": "silver-c-counsilman",
            "na-d-touretski": "silver-d-touretski",
            // Intermediate -> Silver
            "int-a-salo": "silver-a-salo",
            "int-b-bowman": "silver-b-bowman",
            "int-c-touretski": "silver-c-touretski",
            "int-d-reese": "silver-d-reese",
            "int-e-mckeever": "silver-e-mckeever",
            // Advanced -> Gold
            "adv-a-bowman": "gold-a-bowman",
            "adv-b-salo": "gold-b-salo",
            "adv-c-sweetenham": "gold-c-sweetenham",
            "adv-d-touretski": "gold-d-touretski",
            "adv-e-skinner": "gold-e-skinner",
            // Elite -> National
            "elt-a-bowman": "national-a-bowman",
            "elt-b-touretski": "national-b-touretski",
            "elt-c-salo": "national-c-salo",
            "elt-d-sweetenham": "national-d-sweetenham",
        ]
        return Set(ids.map { migrationMap[$0] ?? $0 })
    }

    public static func extractTierSection(content: String, tier: TrainingTier) -> String {
        let header = tierSectionHeader(for: tier)
        guard let start = content.range(of: header) else {
            return "Section not found for tier \(tier.displayName)"
        }
        let remainder = content[start.lowerBound...]
        let endMarkers = [
            "\n### Tier:",
            "\n## Quick Lookup:",
            "\n## Style Selection",
            "\n## Signature Sets",
        ]
        var end = remainder.endIndex
        for marker in endMarkers {
            if let range = remainder.range(of: marker) {
                if range.lowerBound > start.lowerBound && range.lowerBound < end {
                    end = range.lowerBound
                }
            }
        }
        return String(remainder[..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Private

    private static func loadContentUnlocked() -> String? {
        if let cachedContent { return cachedContent }
        guard let url = bundleURL() else { return nil }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        cachedContent = text
        return text
    }

    private static func bundleURL() -> URL? {
        Bundle.main.url(
            forResource: filename,
            withExtension: "md",
            subdirectory: "swimming-strokes"
        )
        ?? Bundle.main.url(
            forResource: filename,
            withExtension: "md",
            subdirectory: "Resources/swimming-strokes"
        )
        ?? Bundle.main.url(forResource: filename, withExtension: "md")
    }

    private static func tierSectionHeader(for tier: TrainingTier) -> String {
        "### Tier: \(tier.displayName)"
    }

    private static func parseOptions(from content: String) -> [CoachingStyleOption] {
        var options: [CoachingStyleOption] = []
        let parts = content.components(separatedBy: "### Tier:")
        for part in parts.dropFirst() {
            guard let tier = tierFromSectionTitle(part) else { continue }
            guard let tableStart = part.range(of: "**Recommended Styles") else { continue }
            let tableRegion = String(part[tableStart.lowerBound...])
            let lines = tableRegion.split(separator: "\n", omittingEmptySubsequences: false)
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.hasPrefix("|"), !trimmed.contains("Option | Style") else { continue }
                let cells = trimmed
                    .split(separator: "|", omittingEmptySubsequences: false)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                guard cells.count >= 4 else { continue }
                let letter = cells[0]
                guard letter.count == 1, letter.first?.isLetter == true else { continue }
                let styleName = cells[1]
                let source = cells[2]
                let whenToUse = cells[3]
                let slug = styleName
                    .lowercased()
                    .replacingOccurrences(of: " ", with: "-")
                    .replacingOccurrences(of: "(", with: "")
                    .replacingOccurrences(of: ")", with: "")
                let tierSlug = tier.rawValue.replacingOccurrences(of: " ", with: "_")
                let id = "\(tierSlug)-\(letter.lowercased())-\(slug)"
                options.append(
                    CoachingStyleOption(
                        id: id,
                        tier: tier,
                        optionLetter: letter,
                        styleName: styleName,
                        source: source,
                        whenToUse: whenToUse
                    )
                )
            }
        }
        return options.isEmpty ? fallbackOptions() : options
    }

    private static func tierFromSectionTitle(_ section: String) -> TrainingTier? {
        let firstLine = section.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? section
        let title = firstLine.trimmingCharacters(in: .whitespaces)
        if title.hasPrefix("Pre-Competitive") { return .preCompetitive }
        if title.hasPrefix("Bronze") { return .bronze }
        if title.hasPrefix("Silver") { return .silver }
        if title.hasPrefix("Gold") { return .gold }
        if title.hasPrefix("Senior") { return .senior }
        if title.hasPrefix("National") { return .national }
        return nil
    }

    private static func fallbackOptions() -> [CoachingStyleOption] {
        [
            CoachingStyleOption(
                id: "silver-a-salo",
                tier: .silver,
                optionLetter: "A",
                styleName: "Salo (data-informed)",
                source: "David Salo",
                whenToUse: "When the swimmer responds to numbers and measurement"
            ),
            CoachingStyleOption(
                id: "silver-d-reese",
                tier: .silver,
                optionLetter: "D",
                styleName: "Reese (consistency)",
                source: "Eddie Reese",
                whenToUse: "When steady progression over seasons is the goal"
            ),
            CoachingStyleOption(
                id: "bronze-a-reese",
                tier: .bronze,
                optionLetter: "A",
                styleName: "Reese (adapted)",
                source: "Eddie Reese",
                whenToUse: "Default — steady, patient, relationship-focused"
            ),
        ]
    }
}
