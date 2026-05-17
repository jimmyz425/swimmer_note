import Foundation

// MARK: - Profile age band (for mapping lookup)

/// Age bands used in the profile → coach-tier table (see swimming-coach-role-reference.md).
public enum ProfileAgeBand: String, Sendable, CaseIterable {
    case under9 = "under_9"
    case ages9to12 = "9_12"
    case ages13to17 = "13_17"
    case adult18Plus = "18_plus"

    public static func from(age: Int) -> ProfileAgeBand {
        switch age {
        case ..<9: return .under9
        case 9...12: return .ages9to12
        case 13...17: return .ages13to17
        default: return .adult18Plus
        }
    }
}

// MARK: - Mapping row (source of truth in code)

/// One row in the USA Swimming profile → coach-reference tier table.
public struct CoachTierProfileMappingRow: Sendable, Equatable {
    public let trainingTier: TrainingTier
    public let subTier: SubTier?
    public let ageBand: ProfileAgeBand?
    public let skillLevel: SkillLevel?
    public let primaryCoachTiers: [CoachSwimmerTier]
    public let alsoConsider: [CoachSwimmerTier]
    public let notes: String

    public init(
        trainingTier: TrainingTier,
        subTier: SubTier? = nil,
        ageBand: ProfileAgeBand? = nil,
        skillLevel: SkillLevel? = nil,
        primaryCoachTiers: [CoachSwimmerTier],
        alsoConsider: [CoachSwimmerTier] = [],
        notes: String = ""
    ) {
        self.trainingTier = trainingTier
        self.subTier = subTier
        self.ageBand = ageBand
        self.skillLevel = skillLevel
        self.primaryCoachTiers = primaryCoachTiers
        self.alsoConsider = alsoConsider
        self.notes = notes
    }
}

// MARK: - Resolver

/// Maps `UserProfile` fields (USA Swimming club tier, sub-tier, age, skill level, distance preference)
/// to coach-reference tiers (YB, YD, NA, INT, ADV, ELT, SPT, DST).
public enum CoachTierProfileMapping {
    /// Authoritative mapping table. Order matters: more specific rows (sub-tier + age + skill) before broad rows.
    public static let table: [CoachTierProfileMappingRow] = [
        // —— Pre-Competitive ——
        CoachTierProfileMappingRow(
            trainingTier: .preCompetitive, ageBand: .under9,
            primaryCoachTiers: [.youthBeginner],
            notes: "Learn-to-swim / water comfort"
        ),
        CoachTierProfileMappingRow(
            trainingTier: .preCompetitive, ageBand: .ages9to12,
            primaryCoachTiers: [.youthDeveloping],
            notes: "FUNdamentals, all four strokes emerging"
        ),
        CoachTierProfileMappingRow(
            trainingTier: .preCompetitive, ageBand: .ages13to17,
            primaryCoachTiers: [.youthDeveloping],
            alsoConsider: [.noviceAdult],
            notes: "Late entry to team; may need NA-style patience if new to structured training"
        ),
        CoachTierProfileMappingRow(
            trainingTier: .preCompetitive, ageBand: .adult18Plus,
            primaryCoachTiers: [.noviceAdult],
            notes: "Adult learn-to-swim in developmental group"
        ),

        // —— Bronze ——
        CoachTierProfileMappingRow(
            trainingTier: .bronze, subTier: .one, ageBand: .ages9to12,
            primaryCoachTiers: [.youthDeveloping],
            notes: "First-year competitive youth"
        ),
        CoachTierProfileMappingRow(
            trainingTier: .bronze, subTier: .two, ageBand: .ages9to12,
            primaryCoachTiers: [.youthDeveloping],
            notes: "Building B times"
        ),
        CoachTierProfileMappingRow(
            trainingTier: .bronze, subTier: .three, ageBand: .ages9to12,
            primaryCoachTiers: [.youthDeveloping],
            alsoConsider: [.intermediate],
            notes: "Preparing for Silver; light INT techniques OK"
        ),
        CoachTierProfileMappingRow(
            trainingTier: .bronze, ageBand: .ages9to12,
            primaryCoachTiers: [.youthDeveloping],
            notes: "Bronze youth (any sub-tier)"
        ),
        CoachTierProfileMappingRow(
            trainingTier: .bronze, subTier: .one, ageBand: .ages13to17,
            primaryCoachTiers: [.noviceAdult],
            alsoConsider: [.youthDeveloping],
            notes: "Teen new to competition"
        ),
        CoachTierProfileMappingRow(
            trainingTier: .bronze, subTier: .two, ageBand: .ages13to17,
            primaryCoachTiers: [.noviceAdult],
            notes: "Teen bronze, technique still inconsistent"
        ),
        CoachTierProfileMappingRow(
            trainingTier: .bronze, subTier: .three, ageBand: .ages13to17,
            primaryCoachTiers: [.intermediate],
            alsoConsider: [.noviceAdult],
            notes: "Bronze 3 teen → Silver transition"
        ),
        CoachTierProfileMappingRow(
            trainingTier: .bronze, ageBand: .ages13to17,
            primaryCoachTiers: [.noviceAdult],
            notes: "Bronze teen default"
        ),
        CoachTierProfileMappingRow(
            trainingTier: .bronze, ageBand: .adult18Plus, skillLevel: .beginner,
            primaryCoachTiers: [.noviceAdult],
            notes: "Masters / adult beginner in bronze group"
        ),
        CoachTierProfileMappingRow(
            trainingTier: .bronze, ageBand: .adult18Plus, skillLevel: .intermediate,
            primaryCoachTiers: [.intermediate],
            alsoConsider: [.noviceAdult],
            notes: "Adult bronze with training history"
        ),
        CoachTierProfileMappingRow(
            trainingTier: .bronze, ageBand: .adult18Plus,
            primaryCoachTiers: [.noviceAdult],
            notes: "Adult bronze default"
        ),

        // —— Silver ——
        CoachTierProfileMappingRow(
            trainingTier: .silver, subTier: .one, ageBand: .ages9to12,
            primaryCoachTiers: [.youthDeveloping],
            alsoConsider: [.intermediate],
            notes: "Young silver; still motor-learning window"
        ),
        CoachTierProfileMappingRow(
            trainingTier: .silver, subTier: .one, ageBand: .ages13to17,
            primaryCoachTiers: [.intermediate],
            notes: "Early silver teen"
        ),
        CoachTierProfileMappingRow(
            trainingTier: .silver, subTier: .two,
            primaryCoachTiers: [.intermediate],
            notes: "Aerobic engine, technique refinement"
        ),
        CoachTierProfileMappingRow(
            trainingTier: .silver, subTier: .three,
            primaryCoachTiers: [.intermediate],
            alsoConsider: [.advanced],
            notes: "Silver 3 → Gold transition"
        ),
        CoachTierProfileMappingRow(
            trainingTier: .silver, ageBand: .ages9to12,
            primaryCoachTiers: [.youthDeveloping],
            alsoConsider: [.intermediate],
            notes: "Silver youth default"
        ),
        CoachTierProfileMappingRow(
            trainingTier: .silver, ageBand: .adult18Plus, skillLevel: .beginner,
            primaryCoachTiers: [.noviceAdult],
            alsoConsider: [.intermediate],
            notes: "Adult in silver group, limited history"
        ),
        CoachTierProfileMappingRow(
            trainingTier: .silver, ageBand: .adult18Plus,
            primaryCoachTiers: [.intermediate],
            notes: "Adult silver / masters age-group"
        ),
        CoachTierProfileMappingRow(
            trainingTier: .silver,
            primaryCoachTiers: [.intermediate],
            notes: "Silver default (club age-group)"
        ),

        // —— Gold ——
        CoachTierProfileMappingRow(
            trainingTier: .gold, ageBand: .ages13to17,
            primaryCoachTiers: [.advanced],
            alsoConsider: [.intermediate],
            notes: "Senior age-group entry"
        ),
        CoachTierProfileMappingRow(
            trainingTier: .gold, ageBand: .adult18Plus, skillLevel: .advanced,
            primaryCoachTiers: [.advanced],
            notes: "Masters gold"
        ),
        CoachTierProfileMappingRow(
            trainingTier: .gold,
            primaryCoachTiers: [.advanced],
            notes: "Gold default — threshold + race pace introduction"
        ),

        // —— Senior ——
        CoachTierProfileMappingRow(
            trainingTier: .senior, skillLevel: .competitive,
            primaryCoachTiers: [.advanced, .elite],
            notes: "Championship group, national meet prep"
        ),
        CoachTierProfileMappingRow(
            trainingTier: .senior,
            primaryCoachTiers: [.advanced],
            alsoConsider: [.elite],
            notes: "Senior default — high volume, race specificity"
        ),

        // —— National ——
        CoachTierProfileMappingRow(
            trainingTier: .national,
            primaryCoachTiers: [.elite],
            notes: "National / elite qualifier group"
        ),

        // —— Adult skill-level fallbacks (any training tier, age 18+) ——
        CoachTierProfileMappingRow(
            trainingTier: .bronze, ageBand: .adult18Plus, skillLevel: .advanced,
            primaryCoachTiers: [.advanced],
            notes: "Adult advanced in lower-named group"
        ),
        CoachTierProfileMappingRow(
            trainingTier: .silver, ageBand: .adult18Plus, skillLevel: .advanced,
            primaryCoachTiers: [.advanced],
            notes: "Adult advanced silver"
        ),
        CoachTierProfileMappingRow(
            trainingTier: .silver, ageBand: .adult18Plus, skillLevel: .competitive,
            primaryCoachTiers: [.advanced, .elite],
            notes: "Adult competitive"
        ),
        CoachTierProfileMappingRow(
            trainingTier: .gold, ageBand: .adult18Plus, skillLevel: .competitive,
            primaryCoachTiers: [.advanced, .elite],
            notes: "Adult competitive gold"
        ),
        CoachTierProfileMappingRow(
            trainingTier: .gold, ageBand: .adult18Plus, skillLevel: .elite,
            primaryCoachTiers: [.elite],
            notes: "Adult elite"
        ),
    ]

    /// Broad fallbacks when no table row matches (should be rare).
    private static let adultSkillFallback: [SkillLevel: [CoachSwimmerTier]] = [
        .beginner: [.noviceAdult],
        .intermediate: [.intermediate],
        .advanced: [.advanced],
        .competitive: [.advanced, .elite],
        .elite: [.elite],
    ]

    private static let youthTierFallback: [TrainingTier: [CoachSwimmerTier]] = [
        .preCompetitive: [.youthDeveloping],
        .bronze: [.youthDeveloping],
        .silver: [.intermediate],
        .gold: [.advanced],
        .senior: [.advanced],
        .national: [.elite],
    ]

    /// Tiers used for LLM context (primary + transitional + event focus).
    public static func resolve(profile: UserProfile?) -> [CoachSwimmerTier] {
        guard let profile else { return [.intermediate] }
        var tiers = primaryCoachTiers(for: profile)
        if let row = matchingRow(for: profile) {
            tiers.append(contentsOf: row.alsoConsider)
        }
        tiers.append(contentsOf: eventFocusTiers(distancePreference: profile.distancePreference))
        return orderedUnique(tiers)
    }

    /// Tiers exposed in the style picker — primary match only, plus SPT/DST when distance preference applies.
    /// Excludes `alsoConsider` so users see one main tier’s options (~4–5), not every adjacent tier.
    public static func coachTiersForStylePicker(profile: UserProfile?) -> [CoachSwimmerTier] {
        guard let profile else { return [.intermediate] }
        var tiers = primaryCoachTiers(for: profile)
        tiers.append(contentsOf: eventFocusTiers(distancePreference: profile.distancePreference))
        return orderedUnique(tiers)
    }

    private static func primaryCoachTiers(for profile: UserProfile) -> [CoachSwimmerTier] {
        let ageBand = ProfileAgeBand.from(age: profile.age)
        if let row = matchingRow(
            trainingTier: profile.trainingTier,
            subTier: profile.subTier,
            ageBand: ageBand,
            skillLevel: profile.age >= 18 ? profile.skillLevel : nil
        ) {
            return row.primaryCoachTiers
        }
        if profile.age >= 18, let fallback = adultSkillFallback[profile.skillLevel] {
            return fallback
        }
        if let fallback = youthTierFallback[profile.trainingTier] {
            return fallback
        }
        return [.intermediate]
    }

    /// Best matching row for display in UI / debugging.
    public static func matchingRow(for profile: UserProfile) -> CoachTierProfileMappingRow? {
        matchingRow(
            trainingTier: profile.trainingTier,
            subTier: profile.subTier,
            ageBand: ProfileAgeBand.from(age: profile.age),
            skillLevel: profile.age >= 18 ? profile.skillLevel : nil
        )
    }

    /// Human-readable mapping explanation for prompts.
    public static func mappingSummary(for profile: UserProfile?) -> String {
        guard let profile else { return "No profile — using INT (intermediate) coach tier." }
        let coachTiers = resolve(profile: profile)
        let codes = coachTiers.map(\.rawValue).joined(separator: ", ")
        let row = matchingRow(for: profile)
        var lines = [
            "Profile: \(profile.trainingTier.displayName) \(profile.subTier.displayName.isEmpty ? "" : profile.subTier.displayName + " · ")\(profile.age)y · skill \(profile.skillLevel.rawValue)",
            "→ Coach tiers: \(codes) (\(coachTiers.map(\.displayName).joined(separator: "; ")))",
        ]
        if let row, !row.notes.isEmpty {
            lines.append("Mapping note: \(row.notes)")
        }
        if profile.distancePreference == .short {
            lines.append("Distance preference: short sprint → includes SPT")
        } else if profile.distancePreference == .long {
            lines.append("Distance preference: long distance → includes DST")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Private

    private static func matchingRow(
        trainingTier: TrainingTier,
        subTier: SubTier,
        ageBand: ProfileAgeBand,
        skillLevel: SkillLevel?
    ) -> CoachTierProfileMappingRow? {
        let candidates = table.filter { row in
            guard row.trainingTier == trainingTier else { return false }
            if let rowSub = row.subTier, rowSub != subTier { return false }
            if let rowAge = row.ageBand, rowAge != ageBand { return false }
            if let rowSkill = row.skillLevel {
                guard let skillLevel, rowSkill == skillLevel else { return false }
            }
            return true
        }

        return candidates.max(by: { specificity($0) < specificity($1) })
    }

    /// Higher = more specific (prefer sub-tier + age + skill over broad rows).
    private static func specificity(_ row: CoachTierProfileMappingRow) -> Int {
        var score = 0
        if row.subTier != nil { score += 4 }
        if row.ageBand != nil { score += 2 }
        if row.skillLevel != nil { score += 1 }
        return score
    }

    private static func eventFocusTiers(distancePreference: DistancePreference) -> [CoachSwimmerTier] {
        switch distancePreference {
        case .short: return [.sprintFocused]
        case .long: return [.distanceFocused]
        case .mid, .na: return []
        }
    }

    private static func orderedUnique(_ tiers: [CoachSwimmerTier]) -> [CoachSwimmerTier] {
        var seen = Set<CoachSwimmerTier>()
        var result: [CoachSwimmerTier] = []
        for tier in tiers where seen.insert(tier).inserted {
            result.append(tier)
        }
        return result
    }
}
