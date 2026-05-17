import Foundation

// MARK: - Weekly Distance Calculation (Shared)

/// Targets weekly pool volume (meters) for prompts and plan logic.
///
/// Primary source: `Resources/swimming-strokes/usa-swimming-club-training-structure.md`
/// — Quick-Reference table (km/week), sub-tier tables (Pre-Comp A/B/C, Bronze 1/2/3, Silver 1/2/3),
/// and "Volume Progression by Group" (lines ~858–867). Each tier/sub-tier uses the **midpoint**
/// of the documented weekly **range** in meters, then scales by actual practices/week using the
/// document's **Practices/Week** (recommended denominator). When `sessionsPerWeek` is unknown
/// (≤ 0), returns the midpoint volume at the tier's typical practice load (no scaling).
///
/// **Per-session planning:** `perSessionPoolVolumeTargetMeters` divides weekly volume by
/// `max(effectiveWeeklySessionCount, maximumPracticesPerWeek)` so when a swimmer drops a day,
/// we still use the tier’s **upper** typical practice count as the divisor — shorter, stabler
/// per-session targets than dividing only by the lower session count.
///
/// LCM: same relative load is often expressed as ~2× SCM distance for comparable time-on-task;
/// that adjustment is preserved below.

// MARK: - Plan context entry point

/// Weekly target from the active profile’s tier/sub-tier. If `profile` is nil, uses **Silver 1**
/// (same default as `buildDefaultOutlinePrompt` when no profile is set).
internal func weeklyDistanceTarget(for context: PlanContext) -> Int {
    let tier: TrainingTier
    let subTier: SubTier
    if let profile = context.profile {
        tier = profile.trainingTier
        subTier = profile.subTier
    } else {
        tier = .silver
        subTier = .one
    }
    return weeklyDistanceTarget(
        tier: tier,
        subTier: subTier,
        sessionsPerWeek: context.sessionsPerWeek,
        poolType: context.poolType
    )
}

// MARK: - Tier + sub-tier (USA Swimming club structure)

/// Documented typical practices/week for scaling (see sub-tier tables, same markdown file).
internal func recommendedPracticesPerWeek(tier: TrainingTier, subTier: SubTier) -> Int {
    switch tier {
    case .preCompetitive:
        switch subTier {
        case .a, .b: return 2
        case .c: return 2 // doc 2–3; use 2 so an extra third practice scales volume up slightly
        default: return 2
        }
    case .bronze:
        switch subTier {
        case .one: return 3
        case .two: return 3 // doc 3–4
        case .three: return 4 // doc: Bronze 3 → 4 practices/week
        default: return 3
        }
    case .silver:
        switch subTier {
        case .one, .two: return 4
        case .three: return 4 // doc 4–5
        default: return 4
        }
    case .gold:
        return 5 // doc 5–6
    case .senior:
        return 6 // doc 6–8
    case .national:
        return 8 // doc 8–12+
    }
}

/// Upper end of documented practices/week (same ranges as `practices_per_week` max in tier guidance).
internal func maximumPracticesPerWeek(tier: TrainingTier, subTier: SubTier) -> Int {
    switch tier {
    case .preCompetitive:
        switch subTier {
        case .a, .b: return 2
        case .c: return 3
        default: return 3
        }
    case .bronze:
        switch subTier {
        case .one: return 3
        case .two: return 4
        case .three: return 4
        default: return 4
        }
    case .silver:
        switch subTier {
        case .one, .two: return 4
        case .three: return 5
        default: return 5
        }
    case .gold:
        return 6
    case .senior:
        return 8
    case .national:
        return 12
    }
}

/// Midpoint of documented weekly distance **range** for this tier/sub-tier (meters, SCM-equivalent).
private func baseWeeklyMeters(tier: TrainingTier, subTier: SubTier) -> Int {
    switch tier {
    case .preCompetitive:
        switch subTier {
        case .a: return 1_750 // 1–2.5 km
        case .b: return 3_000 // 2–4 km
        case .c: return 5_000 // 3–7 km
        default: return 5_500 // whole Pre-Comp group 3–8 km (summary table)
        }
    case .bronze:
        switch subTier {
        case .one: return 6_000 // 4.5–7.5 km
        case .two: return 10_000 // 6–14 km
        case .three: return 14_000 // 10–18 km
        default: return 13_000 // Bronze group 8–18 km
        }
    case .silver:
        switch subTier {
        case .one: return 13_000 // 10–16 km
        case .two: return 16_000 // 12–20 km
        case .three: return 21_000 // 14–28 km
        default: return 21_500 // Silver group 15–28 km
        }
    case .gold:
        return 32_500 // 25–40 km
    case .senior:
        return 50_000 // 40–60 km
    case .national:
        return 65_000 // 50–80+ km
    }
}

internal func weeklyDistanceTarget(tier: TrainingTier, subTier: SubTier, sessionsPerWeek: Int, poolType: PoolType) -> Int {
    let baseWeekly = baseWeeklyMeters(tier: tier, subTier: subTier)
    let adjusted = poolType == .lcm ? baseWeekly * 2 : baseWeekly
    let recommended = recommendedPracticesPerWeek(tier: tier, subTier: subTier)

    if sessionsPerWeek <= 0 {
        return adjusted
    }
    return adjusted * sessionsPerWeek / max(recommended, 1)
}

// MARK: - PlanContext volume (prompts + tools)

extension PlanContext {
    /// Practices/week used in prompts when `sessionsPerWeek` was not set (0): profile target, else tier doc default.
    public var effectiveWeeklySessionCount: Int {
        if sessionsPerWeek > 0 { return sessionsPerWeek }
        if let profile, profile.weeklySessionTarget > 0 { return profile.weeklySessionTarget }
        let tier = profile?.trainingTier ?? .silver
        let sub = profile?.subTier ?? .one
        return recommendedPracticesPerWeek(tier: tier, subTier: sub)
    }

    /// Weekly pool volume target (meters) from tier/sub-tier, profile practices (when wired), and pool type.
    public var weeklyPoolVolumeTargetMeters: Int {
        weeklyDistanceTarget(for: self)
    }

    /// Divisor for per-session pool volume: at least the tier’s **max** documented practices/week,
    /// and at least the swimmer’s effective session count (so extra practices still scale up).
    public var perSessionPoolVolumePlanningDivisor: Int {
        let tier = profile?.trainingTier ?? .silver
        let sub = profile?.subTier ?? .one
        let docMax = maximumPracticesPerWeek(tier: tier, subTier: sub)
        return max(effectiveWeeklySessionCount, docMax, 1)
    }

    /// Target swim meters per pool session for prompts (stable when session count dips within the tier band).
    public var perSessionPoolVolumeTargetMeters: Int {
        weeklyPoolVolumeTargetMeters / perSessionPoolVolumePlanningDivisor
    }
}
