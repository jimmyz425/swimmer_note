import Foundation

// MARK: - Coach swimmer tier (from swimming-coach-role-reference.md)

public enum CoachSwimmerTier: String, CaseIterable, Codable, Sendable, Identifiable {
    case youthBeginner = "YB"
    case youthDeveloping = "YD"
    case noviceAdult = "NA"
    case intermediate = "INT"
    case advanced = "ADV"
    case elite = "ELT"
    case sprintFocused = "SPT"
    case distanceFocused = "DST"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .youthBeginner: return "Youth Beginner (5–9)"
        case .youthDeveloping: return "Youth Developing (9–12)"
        case .noviceAdult: return "Novice Adult"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        case .elite: return "Elite"
        case .sprintFocused: return "Sprint-Focused"
        case .distanceFocused: return "Distance-Focused"
        }
    }
}

// MARK: - Coaching style option

public struct CoachingStyleOption: Identifiable, Hashable, Sendable, Codable {
    /// Stable id, e.g. `int-salo`
    public let id: String
    public let tier: CoachSwimmerTier
    public let optionLetter: String
    public let styleName: String
    public let source: String
    public let whenToUse: String

    public var isDefaultRecommendation: Bool {
        whenToUse.localizedCaseInsensitiveContains("default")
    }

    public init(
        id: String,
        tier: CoachSwimmerTier,
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

    public static func options(for tiers: [CoachSwimmerTier]) -> [CoachingStyleOption] {
        let tierSet = Set(tiers)
        return allOptions().filter { tierSet.contains($0.tier) }
    }

    /// Style options for the planner UI — filtered to picker tiers only.
    public static func optionsForStylePicker(profile: UserProfile?) -> [CoachingStyleOption] {
        options(for: CoachTierProfileMapping.coachTiersForStylePicker(profile: profile))
    }

    /// Options grouped by coach tier (for sectioned UI).
    public static func optionsGroupedForStylePicker(
        profile: UserProfile?
    ) -> [(tier: CoachSwimmerTier, options: [CoachingStyleOption])] {
        CoachTierProfileMapping.coachTiersForStylePicker(profile: profile).compactMap { tier in
            let tierOptions = options(for: [tier])
            guard !tierOptions.isEmpty else { return nil }
            return (tier, tierOptions)
        }
    }

    public static func defaultSelectionIDs(for tiers: [CoachSwimmerTier]) -> Set<String> {
        let available = options(for: tiers)
        let defaults = available.filter(\.isDefaultRecommendation).map(\.id)
        if !defaults.isEmpty { return Set(defaults) }
        return Set(available.prefix(2).map(\.id))
    }

    public static func defaultSelectionIDs(forProfile profile: UserProfile?) -> Set<String> {
        defaultSelectionIDs(for: CoachTierProfileMapping.coachTiersForStylePicker(profile: profile))
    }

    /// Drop selections that are not valid for the current profile’s picker tiers.
    public static func pruneSelection(_ selected: Set<String>, profile: UserProfile?) -> Set<String> {
        let allowed = Set(optionsForStylePicker(profile: profile).map(\.id))
        return selected.intersection(allowed)
    }

    public static func resolvedCoachTiers(profile: UserProfile?) -> [CoachSwimmerTier] {
        CoachTierProfileMapping.resolve(profile: profile)
    }

    public static func extractTierSection(content: String, tier: CoachSwimmerTier) -> String {
        let header = tierSectionHeader(for: tier)
        guard let start = content.range(of: header) else {
            return "Section not found for tier \(tier.rawValue)"
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

    private static func tierSectionHeader(for tier: CoachSwimmerTier) -> String {
        switch tier {
        case .youthBeginner: return "### Tier: Youth Beginner"
        case .youthDeveloping: return "### Tier: Youth Developing"
        case .noviceAdult: return "### Tier: Novice Adult"
        case .intermediate: return "### Tier: Intermediate"
        case .advanced: return "### Tier: Advanced"
        case .elite: return "### Tier: Elite"
        case .sprintFocused: return "### Tier: Sprint-Focused"
        case .distanceFocused: return "### Tier: Distance-Focused"
        }
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
                let id = "\(tier.rawValue.lowercased())-\(letter.lowercased())-\(slug)"
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

    private static func tierFromSectionTitle(_ section: String) -> CoachSwimmerTier? {
        let firstLine = section.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? section
        let title = firstLine.trimmingCharacters(in: .whitespaces)
        if title.hasPrefix("Youth Beginner") { return .youthBeginner }
        if title.hasPrefix("Youth Developing") { return .youthDeveloping }
        if title.hasPrefix("Novice Adult") { return .noviceAdult }
        if title.hasPrefix("Intermediate") { return .intermediate }
        if title.hasPrefix("Advanced") { return .advanced }
        if title.hasPrefix("Elite") { return .elite }
        if title.hasPrefix("Sprint-Focused") { return .sprintFocused }
        if title.hasPrefix("Distance-Focused") { return .distanceFocused }
        return nil
    }

    private static func fallbackOptions() -> [CoachingStyleOption] {
        [
            CoachingStyleOption(
                id: "int-a-salo",
                tier: .intermediate,
                optionLetter: "A",
                styleName: "Salo (data-informed)",
                source: "David Salo",
                whenToUse: "When the swimmer responds to numbers and measurement"
            ),
            CoachingStyleOption(
                id: "int-d-reese",
                tier: .intermediate,
                optionLetter: "D",
                styleName: "Reese (consistency)",
                source: "Eddie Reese",
                whenToUse: "When steady progression over seasons is the goal"
            ),
            CoachingStyleOption(
                id: "na-a-reese",
                tier: .noviceAdult,
                optionLetter: "A",
                styleName: "Reese (consistency)",
                source: "Eddie Reese",
                whenToUse: "Default — steady, patient, relationship-focused"
            ),
        ]
    }
}
