import Foundation

// MARK: - Plan Type Enum

public enum PlanType: String, CaseIterable, Identifiable, Codable {
    case mixed = "Mixed Training"
    case recovery = "Recovery Week"
    case endurance = "Endurance Focus"
    case technique = "Technique Focus"
    case dryLandOnly = "Dry Land Only"
    case racePrep = "Race Prep"
    case speed = "Speed & Sprint"
    // Macrocycle phases (Silver+ only)
    case generalPrep = "General Preparation"
    case specificPrep = "Specific Preparation"
    case preCompetition = "Pre-Competition"
    case competition = "Competition Phase"
    case taper = "Taper"

    public var id: String { rawValue }

    /// Whether this plan type requires advanced tier (Silver+)
    public var requiresAdvancedTier: Bool {
        switch self {
        case .generalPrep, .specificPrep, .preCompetition, .competition, .taper:
            return true
        default:
            return false
        }
    }

    public var description: String {
        switch self {
        case .mixed: "Balanced club training"
        case .recovery: "Active recovery, light technique"
        case .endurance: "Distance and stamina building"
        case .technique: "Low intensity, high quality"
        case .dryLandOnly: "No pool sessions"
        case .racePrep: "Competition readiness"
        case .speed: "Sprint and pace work"
        case .generalPrep: "Base building (Zone 1-2 focus)"
        case .specificPrep: "Threshold development phase"
        case .preCompetition: "Sharpening, race-pace specificity"
        case .competition: "Meet season, high quality"
        case .taper: "10-21 days before major meet"
        }
    }

    public var icon: String {
        switch self {
        case .mixed: "figure.pool.swim"
        case .recovery: "moon"
        case .endurance: "heart"
        case .technique: "figure.pool.swim"
        case .dryLandOnly: "figure.strengthtraining.traditional"
        case .racePrep: "flag"
        case .speed: "bolt"
        case .generalPrep: "chart.line.uptrend.xyaxis"
        case .specificPrep: "flame"
        case .preCompetition: "trophy"
        case .competition: "medal"
        case .taper: "sparkles"
        }
    }
}

// MARK: - Plan Context

public struct PlanContext: Sendable {
    public let profile: UserProfile?
    public let notes: [TrainingNote]
    public let poolType: PoolType
    public let sessionsPerWeek: Int  // 0 = not determined, LLM will decide based on tier guidance
    public let strokeBalance: [StrokeBalanceInfo]
    public let goalProgress: GoalProgressInfo

    public init(
        profile: UserProfile?,
        notes: [TrainingNote],
        poolType: PoolType,
        sessionsPerWeek: Int = 0,  // Default 0 - LLM determines from tier guidance
        strokeBalance: [StrokeBalanceInfo],
        goalProgress: GoalProgressInfo
    ) {
        self.profile = profile
        self.notes = notes
        self.poolType = poolType
        self.sessionsPerWeek = sessionsPerWeek
        self.strokeBalance = strokeBalance
        self.goalProgress = goalProgress
    }
}

public struct StrokeBalanceInfo: Sendable {
    public let stroke: String
    public let sessions: Int
    public let percentage: Int

    public init(stroke: String, sessions: Int, percentage: Int) {
        self.stroke = stroke
        self.sessions = sessions
        self.percentage = percentage
    }
}

public struct GoalProgressInfo: Sendable {
    public let achieved: [GoalSummary]
    public let struggling: [GoalSummary]
    public let inProgress: [GoalSummary]

    public init(achieved: [GoalSummary], struggling: [GoalSummary], inProgress: [GoalSummary]) {
        self.achieved = achieved
        self.struggling = struggling
        self.inProgress = inProgress
    }
}

public struct GoalSummary: Sendable {
    public let stroke: String?
    public let description: String

    public init(stroke: String?, description: String) {
        self.stroke = stroke
        self.description = description
    }
}

// MARK: - Strategy Protocol

public protocol PlanGenerationStrategy: Sendable {
    var planType: PlanType { get }

    func buildSystemRole() -> String
    func buildUserPrompt(context: PlanContext) -> String
    func buildOutlinePrompt(context: PlanContext) -> String  // Phase 1: Rough outline
    func buildDetailPrompt(sessionOutline: SessionOutline, context: PlanContext) -> String  // Phase 2: Detailed session
    func buildDryLandPrompt(outline: WeeklyPlanOutline, context: PlanContext) -> String  // Phase 3: Weekly dryland
    func guidanceFiles() -> [String]
    func coachingRules() -> String
}

// MARK: - Default Two-Phase Implementations

extension PlanGenerationStrategy {
    /// Default Phase 1 prompt - rough weekly outline
    public func buildOutlinePrompt(context: PlanContext) -> String {
        return buildDefaultOutlinePrompt(context, planType: planType)
    }

    /// Default Phase 2 prompt - detailed session for one outline (no dryland)
    public func buildDetailPrompt(sessionOutline: SessionOutline, context: PlanContext) -> String {
        return buildDefaultDetailPrompt(sessionOutline, context: context)
    }

    /// Default Phase 3 prompt - weekly dryland based on full plan
    public func buildDryLandPrompt(outline: WeeklyPlanOutline, context: PlanContext) -> String {
        return buildDefaultDryLandPrompt(outline, context: context)
    }
}

// MARK: - Phase 1: Outline Prompt Builder

/// Build default Phase 1 outline prompt with pre-gathered data
private func buildDefaultOutlinePrompt(_ context: PlanContext, planType: PlanType) -> String {
    // Check if this is a macrocycle phase (requires interval training research reference)
    let isMacrocyclePhase = planType.requiresAdvancedTier

    var prompt = """
    Generate a PHASE 1 WEEKLY PLAN OUTLINE for \(planType.rawValue).
    This is a ROUGH outline - NO detailed sets, just session focuses and structure.

    MANDATORY FIRST STEPS - Call these tools BEFORE generating the outline:

    1. Call read_usa_swimming_structure(section: "all") to get comprehensive tier background:
       - Quick-Reference Summary Table with all tier definitions
       - Zone distribution percentages per tier and sub-tier
       - Volume progression (weekly/per-session distances in km)
       - Practices per week recommendations by tier
       - Sub-tier breakdowns with detailed criteria
       - Training focus allocation by tier

       CRITICAL: Use this document to DETERMINE:
       - Appropriate number of sessions per week for the swimmer's tier/sub-tier
       - Weekly distance target (in meters, convert from km in document)
       - Per-session distance target based on practice duration guidance
       - Zone distribution percentages to follow

    2. Call get_tier_guidance() to get specific guidance for the swimmer's current tier/sub-tier.
       This returns pre-calculated values, but cross-check with the full document for context.

    """

    // Add macrocycle phase-specific tool call
    if isMacrocyclePhase {
        prompt += """
    3. CRITICAL FOR MACROCYCLE PHASE: Call read_interval_research(section: "periodization") to get:
       - Detailed zone distribution percentages for this specific phase
       - Interval characteristics (distance, rest patterns) for the phase
       - Sample week structures for each macrocycle phase
       - Phase progression over training cycles

       MACROCYCLE PHASE CONTEXT:
       - General Preparation: High aerobic volume (60-75% Zone 1-2), threshold introduction (5-10%)
       - Specific Preparation: Reduced aerobic, increased threshold (15-25% Zone 4), VO2max (10-15%)
       - Pre-Competition: Race-pace specificity (15-20% Zone 5-6), reduced volume
       - Competition Phase: High sprint/speed (20-30% Zone 6), race-pace precision
       - Taper: Volume reduction 41-60%, intensity maintained, race-pace focus (30-40% Zone 6)

    """
    }

    if let profile = context.profile {
        prompt += """
        SWIMMER PROFILE:
        - Name: \(profile.name), Age: \(profile.age)
        - Training Tier: \(profile.trainingTier.displayName) (\(profile.trainingTier.fullName))
        - Sub-Tier: \(profile.subTier.displayName)

        CRITICAL: Use read_usa_swimming_structure() to understand what \(profile.trainingTier.displayName) \(profile.subTier.displayName) means.
        The document has:
        - Recommended practices per week for this tier/sub-tier
        - Weekly distance ranges (in km - convert to meters: 1 km = 1000m)
        - Per-session distance ranges based on practice duration
        - Zone distribution percentages specific to this sub-tier

        IMPORTANT: Determine sessions/week from tier guidance, NOT from user input.
        Example: Bronze 1 typically trains 3 sessions/week, Silver 3 typically 4-5 sessions/week.

        Pool Type: \(context.poolType.fullLabel)
        Pool length: \(Int(context.poolType.poolLengthMeters))\(context.poolType == .scy ? "yd" : "m"). Adjust distance targets accordingly.

        """
    } else {
        // Default tier description for intermediate level
        prompt += """
        SWIMMER PROFILE:
        - Training Level: Intermediate (Silver / Age Group)
        - No specific profile set - use Silver 1 defaults

        Pool Type: \(context.poolType.fullLabel)

        """
    }

    // Add recent training context if available
    if !context.notes.isEmpty {
        let recentDates = context.notes.prefix(7).map { $0.date }.joined(separator: ", ")
        prompt += """
        RECENT TRAINING (last 7 sessions): \(recentDates)

        """
    } else {
        prompt += """
        RECENT TRAINING: NO TRAINING HISTORY - This is a NEW swimmer.
        Plan should focus on technique fundamentals and gradual volume introduction.
        Do NOT reference any past sessions, drills, or training patterns.

        """
    }

    prompt += """
    YOUR TASK - Determine and generate:

    STEP 1: From tier guidance, determine:
    - Sessions per week (use practices_per_week recommendation from get_tier_guidance)
    - Weekly total distance (use weekly_distance range, convert km to meters)
    - Per-session target (use per_session_distance range)

    STEP 2: Generate the weekly outline with:
    - Number of sessions = practices_per_week recommendation for tier
    - Each session with appropriate distance based on per_session_distance range
    - Technique focus appropriate for tier's training focus allocation
    - Zone distribution matching tier's zone percentages

    OUTPUT JSON FORMAT (outline only - NO detailed sets):
    {
      "tierGuidance": {
        "tier": "string - tier name from document",
        "subTier": "string - sub-tier name",
        "sessionsPerWeek": "int - determined from tier guidance",
        "weeklyDistanceTarget": "int - meters (converted from km in document)",
        "perSessionTarget": "int - meters",
        "zoneDistribution": {
          "zone0": "string - percentage",
          "zone1": "string - percentage",
          "zone2": "string - percentage",
          "zone3": "string - percentage",
          "zone4": "string - percentage",
          "zone5": "string - percentage",
          "zone6": "string - percentage"
        }
      },
      "overview": {
        "weekFocus": "string - main focus for the week"
      },
      "pastTrainingSummary": "string - 2-3 sentences summarizing recent training patterns",
      "planConnectionRationale": "string - how this week's plan builds on past training",
      "schedule": [
        {
          "sessionNumber": 1,
          "dayOfWeek": "Monday",
          "poolSession": "string - session name",
          "focus": "string - main focus description",
          "sessionType": "string - session type",
          "techniqueFocus": "string - technique emphasis",
          "techniqueFileRef": "string - technique file reference",
          "addressesGoal": "string - which goal this addresses",
          "estimatedDuration": "string - practice duration from tier guidance",
          "estimatedDistance": "string - distance based on per_session range"
        }
      ],
      "notes": "string - weekly rationale"
    }

    RULES:
    - Session count MUST come from tier guidance (practices_per_week), NOT arbitrary selection
    - Weekly distance MUST align with tier's weekly_distance range
    - Per-session distance MUST align with tier's per_session_distance range
    - Zone distribution MUST match tier's percentages (e.g., Bronze 1 has NO Zone 4-6)
    - OUTPUT ONLY JSON (no explanations)
    """
    return prompt
}

// MARK: - Phase 2: Detail Prompt Builder

/// Build default Phase 2 detail prompt for pool sessions (no dryland)
private func buildDefaultDetailPrompt(_ sessionOutline: SessionOutline, context: PlanContext) -> String {
    let cssPace: String
    if let profile = context.profile, let cssHistory = profile.cssHistory, let latestCSS = cssHistory.latestTest {
        cssPace = latestCSS.formattedPace
    } else {
        cssPace = "NOT TESTED"
    }

    let skillLevel = context.profile?.skillLevel.rawValue ?? "intermediate"

    // Extract stroke from session name for evidence-based drill lookup
    let primaryStroke: String
    if sessionOutline.poolSession.contains("Freestyle") { primaryStroke = "freestyle" }
    else if sessionOutline.poolSession.contains("Backstroke") { primaryStroke = "backstroke" }
    else if sessionOutline.poolSession.contains("Breaststroke") { primaryStroke = "breaststroke" }
    else if sessionOutline.poolSession.contains("Butterfly") { primaryStroke = "butterfly" }
    else { primaryStroke = "freestyle" }

    let prompt = """
    Generate PHASE 2 DETAILED SESSION for session #\(sessionOutline.sessionNumber).

    SESSION CONTEXT:
    - Session focus: \(sessionOutline.poolSession) - \(sessionOutline.focus)
    - Technique focus: \(sessionOutline.techniqueFocus ?? "general")
    - Estimated distance: \(sessionOutline.estimatedDistance ?? "~3000m")
    - Primary stroke: \(primaryStroke)

    SWIMMER CONTEXT:
    - Skill Level: \(skillLevel)
    - Pool Type: \(context.poolType.fullLabel)
    - CSS Pace: \(cssPace)/100m

    MANDATORY — Evidence-Based Secondary Drill Set:
    1. Call read_evidence_drills(stroke="\(primaryStroke)") to get the evidence-based drill library for this stroke.
    2. Pick ONE drill from the tool result that best matches this session's focus.
    3. Build the secondarySet JSON using that drill's specifications (distance, equipment, level adjustment).
    4. Include the evidence citation from the tool result in sessionNotes.

    OUTPUT JSON FORMAT (detailed session with sets):
    {
      "sessionNumber": \(sessionOutline.sessionNumber),
      "focus": "\(sessionOutline.focus)",
      "techniqueFocus": "\(sessionOutline.techniqueFocus ?? "general")",
      "warmUp": {
        "sets": [
          {"repeatCount": 4, "distancePerRep": 100, "swimSeconds": 120, "item": "easy freestyle", "zone": 1, "restSeconds": 15}
        ],
        "zone": 1
      },
      "drillSet": {
        "sets": [
          {"repeatCount": 3, "distancePerRep": 50, "swimSeconds": 60, "item": "drill", "zone": 2, "restSeconds": 12}
        ],
        "zone": 2
      },
      "secondarySet": {
        "sets": [
          {"repeatCount": 6, "distancePerRep": 50, "swimSeconds": 45, "item": "drill name from read_evidence_drills result", "zone": 2, "restSeconds": 15}
        ],
        "zone": 2
      },
      "mainSet": {
        "sets": [
          {"repeatCount": 8, "distancePerRep": 100, "swimSeconds": 85, "item": "freestyle tempo", "zone": 3, "restSeconds": 10}
        ],
        "zone": 3
      },
      "coolDown": {
        "sets": [
          {"repeatCount": 2, "distancePerRep": 100, "swimSeconds": 120, "item": "easy mixed", "zone": 0, "restSeconds": 30}
        ],
        "zone": 0
      },
      "sessionNotes": "string - coaching tips for this session, include evidence-based drill source",
      "progressionRationale": "string - why this progression"
    }

    OUTPUT ONLY JSON (no explanations).
    """

    return prompt
}

// MARK: - Phase 3: Dry Land Prompt Builder

/// Build default Phase 3 prompt for weekly dryland based on full plan
private func buildDefaultDryLandPrompt(_ outline: WeeklyPlanOutline, context: PlanContext) -> String {
    // Summarize the week's technique focuses
    let techniqueFocuses = outline.schedule.compactMap { $0.techniqueFocus }.joined(separator: ", ")
    let strokes = outline.schedule.compactMap { session -> String? in
        // Extract stroke from poolSession if possible
        if session.poolSession.contains("Freestyle") { return "freestyle" }
        if session.poolSession.contains("Backstroke") { return "backstroke" }
        if session.poolSession.contains("Breaststroke") { return "breaststroke" }
        if session.poolSession.contains("Butterfly") { return "butterfly" }
        return nil
    }
    let uniqueStrokes = Array(Set(strokes)).joined(separator: ", ")

    let skillLevel = context.profile?.skillLevel.rawValue ?? "intermediate"

    let prompt = """
    Generate DRY LAND EXERCISES to complement this week's swimming training plan.

    WEEKLY POOL TRAINING SUMMARY:
    - Sessions: \(outline.schedule.count)
    - Technique Focuses: \(techniqueFocuses)
    - Strokes Covered: \(uniqueStrokes.isEmpty ? "mixed" : uniqueStrokes)
    - Week Focus: \(outline.overview.weekFocus)

    SWIMMER CONTEXT:
    - Skill Level: \(skillLevel)

    IMPORTANT: You MUST call get_dry_land_exercises for EACH stroke covered this week BEFORE generating exercises.
    - Call: get_dry_land_exercises(stroke="freestyle") to get available exercises
    - Call: get_dry_land_exercises(stroke="backstroke") if backstroke is covered
    - Call: get_dry_land_exercises(stroke="breaststroke") if breaststroke is covered
    - Call: get_dry_land_exercises(stroke="butterfly") if butterfly is covered

    YOU MUST ONLY USE EXERCISES RETURNED BY THE TOOL. Do NOT invent or create new exercises. If you need an exercise that isn't in the returned list, skip it.

    DRY LAND REQUIREMENTS:
    1. Generate 5-7 exercises that complement the pool training
    2. Target areas based on technique focuses: Core stability, Rotation power, Shoulder strength, Flexibility
    3. Match exercises to swimmer's skill level
    4. Use exercise IDs from tool results (e.g., "plank-hold", "medicine-ball-rotational-throws")

    OUTPUT JSON FORMAT:
    {
      "dryLandExercises": [
        {"stroke": "freestyle", "exerciseId": "plank-hold", "setsReps": "3x30s"},
        {"stroke": "freestyle", "exerciseId": "medicine-ball-rotational-throws", "setsReps": "3x10"},
        {"stroke": "backstroke", "exerciseId": "reverse-plank", "setsReps": "3x20s"}
      ],
      "weeklyRationale": "string - why these exercises complement the pool training"
    }

    RULES:
    - Return exerciseId (NOT exercise name) - use IDs from get_dry_land_exercises tool (e.g., "plank-hold")
    - Each exercise must have: stroke, exerciseId, setsReps format (e.g., "3x10", "3x30s")
    - Distribute exercises across the week's technique focuses
    - OUTPUT ONLY JSON (no explanations)
    """

    return prompt
}

// MARK: - Tier Description Helper

/// Generate detailed tier description for LLM prompt
private func buildTierDescription(_ tier: TrainingTier, _ subTier: SubTier) -> String {
    let tierInfo = getTierInfo(tier)
    let subTierInfo = getSubTierInfo(subTier, tier)

    return """
    Tier: \(tier.displayName) (\(tier.fullName))
    Sub-tier: \(subTier.displayName)
    Typical Age Range: \(tier.ageRange)
    Time Standards: \(tier.timeStandardReference)

    TRAINING CHARACTERISTICS:
    - Practices per week: \(tierInfo.practicesPerWeek)
    - Practice duration: \(tierInfo.practiceDuration)
    - Weekly distance: \(tierInfo.weeklyDistance)
    - Per-session target: \(tierInfo.perSessionTarget)

    TRAINING FOCUS ALLOCATION:
    - Technique: \(tierInfo.techniquePercent)%
    - Aerobic base: \(tierInfo.aerobicPercent)%
    - Threshold/tempo: \(tierInfo.thresholdPercent)%
    - Race pace/sprint: \(tierInfo.sprintPercent)%

    TRAINING ZONE DISTRIBUTION:
    - Zone 0 (Recovery): \(tierInfo.zone0Percent)%
    - Zone 1 (Aerobic base): \(tierInfo.zone1Percent)%
    - Zone 2 (Aerobic endurance): \(tierInfo.zone2Percent)%
    - Zone 3 (Tempo): \(tierInfo.zone3Percent)%
    - Zone 4+ (Threshold/Sprint): \(tierInfo.zone4PlusPercent)%

    SWIMMER CAPABILITIES:
    \(tierInfo.capabilities)

    SUB-TIER INDICATOR: \(subTierInfo)
    """
}

/// Tier-specific training info
private struct TierInfo {
    let practicesPerWeek: String
    let practiceDuration: String
    let weeklyDistance: String
    let perSessionTarget: String
    let techniquePercent: Int
    let aerobicPercent: Int
    let thresholdPercent: Int
    let sprintPercent: Int
    let zone0Percent: Int
    let zone1Percent: Int
    let zone2Percent: Int
    let zone3Percent: Int
    let zone4PlusPercent: Int
    let capabilities: String
}

/// Get training info for a tier
private func getTierInfo(_ tier: TrainingTier) -> TierInfo {
    switch tier {
    case .preCompetitive:
        return TierInfo(
            practicesPerWeek: "2-3",
            practiceDuration: "45-60 min",
            weeklyDistance: "3-8 km (3,000-8,000m)",
            perSessionTarget: "1,500-2,500m",
            techniquePercent: 65,
            aerobicPercent: 20,
            thresholdPercent: 5,
            sprintPercent: 0,
            zone0Percent: 15,
            zone1Percent: 60,
            zone2Percent: 20,
            zone3Percent: 5,
            zone4PlusPercent: 0,
            capabilities: """
            - Learning water comfort and basic stroke mechanics
            - Developing all four strokes with focus on freestyle and backstroke
            - Can swim 25 yards freestyle with side breathing
            - Can swim 25 yards backstroke with alternating arm motion
            - Tread water 1-2 minutes, submerge face and blow bubbles
            - No time standards required - focus on skill acquisition and fun
            """
        )
    case .bronze:
        return TierInfo(
            practicesPerWeek: "3-4",
            practiceDuration: "60-75 min",
            weeklyDistance: "8-18 km (8,000-18,000m)",
            perSessionTarget: "2,500-4,500m",
            techniquePercent: 45,
            aerobicPercent: 25,
            thresholdPercent: 10,
            sprintPercent: 5,
            zone0Percent: 10,
            zone1Percent: 55,
            zone2Percent: 20,
            zone3Percent: 10,
            zone4PlusPercent: 5,
            capabilities: """
            - Proficient in all four strokes (25 yards each, legal technique)
            - Can swim 100-200 yards continuously without stopping
            - Basic flip turn (may not be fast, but legal)
            - Working toward first B times
            - Focus: stroke refinement, all 4 strokes, starts/turns
            """
        )
    case .silver:
        return TierInfo(
            practicesPerWeek: "4-5",
            practiceDuration: "75-90 min",
            weeklyDistance: "15-28 km (15,000-28,000m)",
            perSessionTarget: "4,000-6,000m",
            techniquePercent: 35,
            aerobicPercent: 35,
            thresholdPercent: 15,
            sprintPercent: 10,
            zone0Percent: 10,
            zone1Percent: 50,
            zone2Percent: 25,
            zone3Percent: 10,
            zone4PlusPercent: 5,
            capabilities: """
            - Solid stroke technique in all four strokes
            - Can handle interval training (swimming on send-off times)
            - Developing aerobic endurance base
            - Working toward A and AA time standards
            - Focus: refinement, aerobic base building, threshold introduction
            """
        )
    case .gold:
        return TierInfo(
            practicesPerWeek: "5-6",
            practiceDuration: "90-105 min",
            weeklyDistance: "25-40 km (25,000-40,000m)",
            perSessionTarget: "5,000-7,000m",
            techniquePercent: 25,
            aerobicPercent: 35,
            thresholdPercent: 20,
            sprintPercent: 15,
            zone0Percent: 5,
            zone1Percent: 40,
            zone2Percent: 30,
            zone3Percent: 15,
            zone4PlusPercent: 10,
            capabilities: """
            - Strong technique foundation, stroke-specific refinements
            - CSS pace understanding and training zone work
            - Threshold training introduced
            - Working toward AA and AAA times, Zone qualifiers
            - Focus: threshold introduction, race strategy, volume increase
            """
        )
    case .senior:
        return TierInfo(
            practicesPerWeek: "6-8",
            practiceDuration: "90-120 min",
            weeklyDistance: "40-60 km (40,000-60,000m)",
            perSessionTarget: "6,000-8,000m",
            techniquePercent: 20,
            aerobicPercent: 30,
            thresholdPercent: 25,
            sprintPercent: 20,
            zone0Percent: 5,
            zone1Percent: 30,
            zone2Percent: 25,
            zone3Percent: 20,
            zone4PlusPercent: 20,
            capabilities: """
            - Advanced stroke technique at race pace
            - High-volume aerobic training
            - Threshold and VO2max work
            - Working toward AAA-AAAA times, Junior/Senior Nationals
            - Focus: race pace, lactate tolerance, event specialization
            """
        )
    case .national:
        return TierInfo(
            practicesPerWeek: "8-12",
            practiceDuration: "120-180 min",
            weeklyDistance: "50-80+ km (50,000-80,000m+)",
            perSessionTarget: "7,000-10,000m",
            techniquePercent: 15,
            aerobicPercent: 25,
            thresholdPercent: 30,
            sprintPercent: 25,
            zone0Percent: 5,
            zone1Percent: 25,
            zone2Percent: 20,
            zone3Percent: 25,
            zone4PlusPercent: 25,
            capabilities: """
            - Elite-level technique, fine-tuning race mechanics
            - Peak performance training
            - Race simulation and taper expertise
            - AAAA times, National cuts, International qualifiers
            - Focus: peak performance, event specialization, mental preparation
            """
        )
    }
}

/// Get sub-tier indicator description
private func getSubTierInfo(_ subTier: SubTier, _ tier: TrainingTier) -> String {
    switch subTier {
    case .a:
        return "A - Developing, newest to this tier group, still building foundational skills"
    case .b:
        return "B - Progressing, mid-level within tier, showing consistent improvement"
    case .c:
        return "C - Advancing, ready for promotion to next tier, meeting most criteria"
    case .one:
        return "1 - Entry level in this tier, building volume and skills for the group"
    case .two:
        return "2 - Mid-level, comfortable with tier expectations, steady improvement"
    case .three:
        return "3 - Top of tier, ready for next group, meeting time standards"
    case .none:
        return "Single-level tier (no sub-tiers)"
    }
}

// MARK: - Strategy Factory

public struct PlanStrategyFactory: Sendable {
    public static func strategy(for type: PlanType) -> PlanGenerationStrategy {
        switch type {
        case .mixed: return MixedTrainingStrategy()
        case .recovery: return RecoveryStrategy()
        case .endurance: return EnduranceStrategy()
        case .technique: return TechniqueFocusStrategy()
        case .dryLandOnly: return DryLandOnlyStrategy()
        case .racePrep: return RacePrepStrategy()
        case .speed: return SpeedSprintStrategy()
        // Macrocycle phases (Silver+ only)
        case .generalPrep: return GeneralPrepStrategy()
        case .specificPrep: return SpecificPrepStrategy()
        case .preCompetition: return PreCompetitionStrategy()
        case .competition: return CompetitionPhaseStrategy()
        case .taper: return TaperStrategy()
        }
    }
}

// MARK: - Mixed Training Strategy (Default)

public struct MixedTrainingStrategy: PlanGenerationStrategy, Sendable {
    public var planType: PlanType { .mixed }

    public func buildSystemRole() -> String {
        return "expert_swimming_coach"
    }

    public func buildUserPrompt(context: PlanContext) -> String {
        // Compute weekly total for self-review using tier-based calculation
        let weeklyTotal: Int
        if let profile = context.profile {
            weeklyTotal = weeklyDistanceTarget(
                tier: profile.trainingTier,
                subTier: profile.subTier,
                sessionsPerWeek: context.sessionsPerWeek,
                poolType: context.poolType
            )
        } else {
            weeklyTotal = weeklyDistanceTarget(
                skillLevel: .intermediate,
                sessionsPerWeek: context.sessionsPerWeek,
                poolType: context.poolType
            )
        }
        let perSessionTarget = weeklyTotal / max(context.sessionsPerWeek, 1)

        return """
        MANDATORY FIRST STEPS (call these tools BEFORE generating the plan):

        1. Call get_tier_guidance() to get training guidance based on the swimmer's competitive tier.
           - Returns tier and sub-tier (Pre-Competitive, Bronze 1/2/3, Silver 1/2/3, Gold, Senior, National)
           - Returns recommended weekly distance and per-session distance ranges
           - Returns zone distribution percentages appropriate for the tier (Zone 0-6)
           - Returns training focus priorities
           - CRITICAL: Session totals MUST align with per-session distance guidance
           - CRITICAL: Zone distribution MUST follow tier-appropriate percentages

        2. Call get_css_info() to get the swimmer's Critical Swim Speed (CSS) test results.
           - CSS determines training zone paces (Zone 0-6)
           - Use CSS pace + offsets to set accurate interval targets
           - If no CSS available, use skill level fallback

        3. Call read_interval_research(section: "zones") to understand:
           - Zone definitions and pace targets
           - Volume recommendations by skill level
           - Rest interval guidelines
           - Sample sets for each zone

        4. Call read_interval_research(section: "levels") for swimmer-specific adjustments.

        AFTER reading tier guidance, CSS info, and interval research, use that knowledge to:

        STEP 1: DETERMINE SESSION ZONES AND VOLUMES FROM TIER GUIDANCE
        - Use tier guidance zone distribution (NOT generic 30/40/20/10 split)
        - Lower tiers (Bronze/Silver): More Zone 1-2, minimal Zone 4-5
        - Higher tiers (Gold/Senior/National): More Zone 3-4, structured Zone 5-6
        - Match per-session distance to tier guidance range
        - Match weekly total to tier guidance weekly distance

        STEP 2: BUILD THE PLAN

        """ + buildBasePrompt(context) + """

        RULES:
        - ACHIEVED goals → next technique OR revisit fundamentals
        - STRUGGLING → easier prerequisite
        - FUNDAMENTALS (1-3): include in 30%+ of sessions - never skip
        - NEGLECTED strokes: at least 1 session each

        SESSION TYPES: fundamental revisit / current level / stretch goal

        CRITICAL: Use structured "sets" format for accurate distance calculation!
        DO NOT manually calculate distance - the system will compute it from sets.

        SET FORMAT (use this in ALL segments - include zone and restSeconds per set):
        "sets": [
          {"repeatCount": 6, "distancePerRep": 50, "swimSeconds": 55, "item": "breaststroke swim", "zone": 2, "restSeconds": 15},
          {"repeatCount": 4, "distancePerRep": 25, "swimSeconds": 28, "item": "streamline push-off", "zone": 1, "restSeconds": 10},
          {"repeatCount": 2, "swimSeconds": 30, "item": "vertical kick", "zone": 3, "restSeconds": 20}
        ]

        Set types:
        - Distance set: {"repeatCount": N, "distancePerRep": M, "swimSeconds": S, "item": "description", "zone": Z, "restSeconds": R}
        - Timed set: {"repeatCount": N, "swimSeconds": S, "item": "description", "zone": Z, "restSeconds": R}

        SWIM SECONDS / EFFORT GUIDANCE:
        IF CSS info is available (call get_css_info() to check):
          - Include "swimSeconds" in each set = distance × zone pace (e.g., 100m @ Zone 4 CSS pace = ~77s)
          - swimSeconds is displayed as "1:17" timing per rep
        IF CSS info is NOT available (no CSS test done):
          - Include "effortPercent" in notes field (e.g., "notes": "85% effort")
          - Use effort percentages as intensity guide: Zone 0-1: 50-60%, Zone 2-3: 70-80%, Zone 4: 85-90%, Zone 5: 95-100%, Zone 6: Max sprint
          - Skip swimSeconds field when no CSS - system will show zone + effort% instead

        REST INTERVALS BY ZONE (from interval research - call read_interval_research to confirm):
        Zone 0: 60-120s rest (50-100% of work time)
        Zone 1: 12-20s rest (15-25% of work time)
        Zone 2: 8-16s rest (10-20% of work time)
        Zone 3: 8-12s rest (10-15% of work time)
        Zone 4: 4-12s rest (5-15% of work time)
        Zone 5: 24-40s rest (30-50% of work time)
        Zone 6: 180-300s rest (3-5 minutes for pure speed)

        IMPORTANT: Include "zone" field in EACH set for intensity tracking.
        IMPORTANT: Include "restSeconds" field in EACH set based on zone.
        IMPORTANT: If CSS available: include swimSeconds. If no CSS: include effort% in notes.

        ZONE SPECIFICATION (CRITICAL - include zone field in each segment):
        Zone 0: Recovery (CSS +20-30s/100m)
        Zone 1: Aerobic Base (CSS +10-15s/100m)
        Zone 2: Aerobic Endurance (CSS +5-10s/100m)
        Zone 3: Tempo/AeT (CSS +0-5s/100m)
        Zone 4: Lactate Threshold (CSS to -2s/100m)
        Zone 5: VO2max (CSS -3-6s/100m)
        Zone 6: Sprint (Race pace)

        ZONE DISTRIBUTION BY TIER (from get_tier_guidance - MUST follow these):
        Pre-Competitive: 60-70% Z1, 10-15% Z2, 0-5% Z3, NO Z4-Z6
        Bronze 1: 55-60% Z1, 15-20% Z2, 5-10% Z3, NO Z4-Z6
        Bronze 2: 50-55% Z1, 20-25% Z2, 10-15% Z3, 0-5% Z4, NO Z5-Z6
        Bronze 3: 45-50% Z1, 25-30% Z2, 10-15% Z3, 5% Z4, NO Z5-Z6
        Silver 1: 45-50% Z1, 25-30% Z2, 10-15% Z3, 5% Z4, NO Z5-Z6
        Silver 2: 40-45% Z1, 25-30% Z2, 15% Z3, 5-10% Z4, 0-5% Z5
        Silver 3: 35-40% Z1, 25-30% Z2, 15-20% Z3, 10% Z4, 5% Z5, 0-3% Z6
        Gold: 35-40% Z1, 25-30% Z2, 15-20% Z3, 5-10% Z4, 0-5% Z5, 0-3% Z6
        Senior: 25-30% Z1, 25-30% Z2, 15-20% Z3, 10-15% Z4, 5-10% Z5, 3-5% Z6
        National: 15-20% Z1, 20-25% Z2, 15-20% Z3, 15-20% Z4, 10-15% Z5, 5-10% Z6

        CRITICAL: Zone distribution MUST match the swimmer's tier from get_tier_guidance()!
        Example: A Bronze 1 swimmer should NOT have Zone 4-5 work. A Senior swimmer needs structured Zone 4-5.

        SESSION PLANNING TEMPLATE FORMAT:
        Warm-up: Zone 0-1 (easy, progressive build, 12-20s rest)
        Drill/Pre-set: Zone 1-2 (technique focus, 10-16s rest)
        Main Set: Zone ___ (primary training zone - specify based on session focus AND TIER ALLOWANCE)
        Secondary Set: Zone ___ (optional - complementary work)
        Cool-down: Zone 0 (recovery, 60-120s rest)
        Notes/Observations: coaching tips for this session

        JSON OUTPUT (use sets array with zone, swimSeconds, and restSeconds - distance field computed automatically):
        {
          "overview": {
            "weekFocus": "string - main focus for the week",
            "fundamentalRevisitPlan": "string - which fundamentals to revisit"
          },
          "schedule": [{
            "sessionNumber": 1,
            "poolSession": "string - session name like 'Freestyle Sprint Focus'",
            "focus": "string - focus description",
            "sessionType": "string - type like 'fundamental revisit' or 'current level'"
          }],
          "detailedSessions": [{
            "sessionNumber": 1,
            "focus": "string - session focus",
            "techniqueFocus": "string - technique emphasis",
            "techniqueFileRef": "string - technique file reference",
            "sessionType": "string - session type",
            "warmUp": {"sets": [{"repeatCount": 6, "distancePerRep": 50, "swimSeconds": 55, "item": "easy freestyle", "zone": 1, "restSeconds": 15}], "zone": 1},
            "drillSet": {"sets": [{"repeatCount": 3, "distancePerRep": 100, "swimSeconds": 105, "item": "6-1-6 drill", "zone": 2, "restSeconds": 12}], "zone": 2},
            "mainSet": {"sets": [
              {"repeatCount": 5, "distancePerRep": 100, "swimSeconds": 77, "item": "freestyle swim", "zone": 4, "restSeconds": 8},
              {"repeatCount": 4, "distancePerRep": 50, "swimSeconds": 38, "item": "pace work", "zone": 5, "restSeconds": 30}
            ], "zone": 4},
            "secondarySet": {"sets": [{"repeatCount": 4, "distancePerRep": 50, "swimSeconds": 50, "item": "backstroke", "zone": 2, "restSeconds": 15}], "zone": 2},
            "coolDown": {"sets": [{"repeatCount": 2, "distancePerRep": 50, "swimSeconds": 60, "item": "easy backstroke", "zone": 0, "restSeconds": 30}], "zone": 0},
            "sessionNotes": "string - coaching tips and observations for this session",
            "progressionRationale": "string - why this progression"
          }],
          "dryLandProgram": [{
            "exercise": "string - exercise name",
            "setsReps": "string like '3x15'",
            "techniqueSupport": "string - which stroke this helps"
          }],
          "goalProgressPlan": {
            "continueGoals": ["array of goal descriptions"],
            "achievedGoalsNextLevel": ["array of next level goals"],
            "fundamentalRevisitGoals": ["array of fundamental goals"],
            "newGoals": ["array of new goals"]
          },
          "notes": "string - progression rationale"
        }

        IMPORTANT: DO NOT include "distance" or "description" fields - only use "sets" array.
        IMPORTANT: Each set must have repeatCount (Int), item (String), zone (Int 0-6), swimSeconds (Int), and restSeconds (Int).
        IMPORTANT: distancePerRep and durationSeconds are Int, not String.
        IMPORTANT: Include "restSeconds" in EACH set based on zone from interval research.
        IMPORTANT: Include "secondarySet" when session has complementary work (optional).
        IMPORTANT: Include "sessionNotes" for coaching tips specific to the session.

        SELF-REVIEW (CRITICAL - perform before outputting):
        After generating the JSON, verify:
        1. TIER ALIGNMENT: Check get_tier_guidance() results:
           - Session distance within per_session_distance range for tier
           - Weekly total within weekly_distance range for tier
           - Zone distribution matches tier percentages (no Zone 4-6 for Bronze, etc.)
        2. DISTANCE MATH: For EACH segment, calculate sum of (repeatCount × distancePerRep) for all sets.
           - Example: sets=[{"repeatCount":6,"distancePerRep":50},{"repeatCount":4,"distancePerRep":25}]
           - Check: 6×50=300, 4×25=100, total=400m ✓
           - If mismatch found, CORRECT the sets before outputting.
        3. SESSION TOTALS: Each session's segments (warmUp+drillSet+mainSet+secondarySet+coolDown) should total roughly the per-session target.
           - Target: ~\(perSessionTarget)m per session (weekly total divided by \(context.sessionsPerWeek) sessions).
           - MUST be within tier guidance per_session_distance range.
        4. ZONE FIELDS: Each set AND each segment has zone field (Int 0-6):
           - Warm-up sets: zone 0-1
           - Drill/Pre-set sets: zone 1-2
           - Main Set sets: zone based on session focus AND TIER ALLOWANCE
           - Secondary Set sets: zone based on complementary work
           - Cool-down sets: zone 0
        5. ZONE DISTRIBUTION: Check that zone usage matches tier from get_tier_guidance():
           - Pre-Comp/Bronze 1-2: NO Zone 4, 5, 6 allowed
           - Bronze 3/Silver 1: Zone 4 limited to 5%
           - Silver 2-3/Gold: Zone 4-5 allowed, Zone 6 limited
           - Senior/National: All zones allowed with proper distribution
        6. SWIM SECONDS / EFFORT: Each set has either swimSeconds OR effort guidance:
           - IF CSS available: swimSeconds = distance × zone pace (e.g., 100m @ Z4 = ~77s)
           - IF no CSS: include effort% in notes (e.g., "85% effort")
        7. REST SECONDS: Each set has restSeconds appropriate for its zone:
           - Zone 0: 60-120s
           - Zone 1: 12-20s
           - Zone 2: 8-16s
           - Zone 3: 8-12s
           - Zone 4: 4-12s
           - Zone 5: 24-40s
           - Zone 6: 180-300s
        8. JSON VALIDITY: All distancePerRep, swimSeconds, restSeconds are Int (not strings).
           - All repeatCount are Int > 0.
           - All zone fields are Int 0-6 (in both sets AND segments).
           - All item fields are non-empty strings.
        9. COMPLETE SESSIONS: Generate exactly \(context.sessionsPerWeek) sessions.
        10. FUNDAMENTALS: At least 30% of sessions include fundamental revisit.

        If any check fails, fix the JSON before outputting the final result.

        Generate \(context.sessionsPerWeek) sessions. Include fundamentals in 30%+ sessions. Match drills to skill tier.
        USE TIER GUIDANCE for zone distribution and session volumes.
        USE CSS ZONE PACES for interval targets when CSS is available.
        OUTPUT ONLY JSON (after self-review passes).
        """
    }

    public func guidanceFiles() -> [String] {
        return ["coach_prompt.md", "swimming-interval-training-research.md"]
    }

    public func coachingRules() -> String {
        return """
        SESSION BALANCE: 30% fundamentals, 50% current-level, 20% stretch.
        For drills: read_technique_file("{stroke}-{number}-{name}.md") → tiered targets.
        For intervals: get_css_info() + read_interval_research("zones") → accurate send-off times.
        """
    }

    private func buildBasePrompt(_ context: PlanContext) -> String {
        var prompt = "Generate a weekly training plan.\n"

        // Profile context
        if let profile = context.profile {
            prompt += """
            SWIMMER: \(profile.name), Age \(profile.age), Level \(profile.skillLevel.rawValue)
            TARGET: \(profile.weeklySessionTarget) sessions/week
            STROKES: \(profile.preferredStrokes.map { $0.rawValue }.joined(separator: ", "))
            PBs: Free \(profile.personalBests.freestyle50m ?? 0)s, Back \(profile.personalBests.backstroke50m ?? 0)s

            """

            // Include user's revisit nodes if any
            if !profile.revisitNodes.isEmpty {
                let revisitList = profile.revisitNodes.flatMap { strokeId, nodeIds in
                    nodeIds.map { nodeId in "\(strokeId):\(nodeId)" }
                }.joined(separator: ", ")
                prompt += """
                USER REVISIT FOCUS: The swimmer has marked these techniques for regular practice: \(revisitList)
                Prioritize these in fundamental revisit sessions.

                """
            }

            // Include CSS summary if available
            if let cssHistory = profile.cssHistory, let latestCSS = cssHistory.latestTest {
                prompt += """
                CSS: \(latestCSS.formattedPace)/100m (tested \(latestCSS.date), \(latestCSS.strokeId.rawValue))
                CSS TREND: \(cssHistory.trend?.rawValue ?? "stable")

                """
            } else {
                prompt += """
                CSS: NOT TESTED - Call get_css_info() for fallback zone estimation, or recommend CSS test.

                """
            }
        }

        // Weekly total distance guidance based on training tier
        let weeklyTotal: Int
        if let profile = context.profile {
            weeklyTotal = weeklyDistanceTarget(
                tier: profile.trainingTier,
                subTier: profile.subTier,
                sessionsPerWeek: context.sessionsPerWeek,
                poolType: context.poolType
            )
        } else {
            weeklyTotal = weeklyDistanceTarget(
                skillLevel: .intermediate,
                sessionsPerWeek: context.sessionsPerWeek,
                poolType: context.poolType
            )
        }
        prompt += """
        WEEKLY TOTAL DISTANCE: \(weeklyTotal) across ALL sessions combined.
        Each session should be roughly \(weeklyTotal / context.sessionsPerWeek)m (divide weekly total by session count).

        """

        // Technique difficulty reference
        prompt += """
        TECHNIQUE LEVELS (1-9):
        FREE: 1-BodyPos | 2-Kick | 3-Breath | 4-Rotation | 5-Entry | 6-Recovery | 7-Timing | 8-Catch | 9-Pull
        BACK: 1-BodyPos | 2-Head | 3-Kick | 4-Breath | 5-Rotation | 6-Entry | 7-Timing | 8-Catch | 9-Pull
        BREAST: 1-BodyPos | 2-Streamline | 3-Breath | 4-Pull | 5-Kick | 6-Timing | 7-Turns
        BUTTERFLY: 1-BodyPos | 2-Dolphin | 3-Entry | 4-Pull | 5-Recovery | 6-Breath | 7-Timing | 8-Coord

        """

        // Stroke balance
        if !context.strokeBalance.isEmpty && context.strokeBalance.contains(where: { $0.sessions > 0 }) {
            prompt += "STROKE BALANCE (last 14 days):\n"
            for balance in context.strokeBalance {
                prompt += "- \(balance.stroke): \(balance.sessions) sessions (\(balance.percentage)%)\n"
            }
            let neglected = context.strokeBalance.filter { $0.sessions == 0 }.map { $0.stroke }
            if !neglected.isEmpty {
                prompt += "NEGLECTED: \(neglected.joined(separator: ", ")) - include this week\n"
            }
        } else {
            prompt += "STROKE BALANCE: NO TRAINING HISTORY - New swimmer, no stroke focus data available.\n"
        }

        // Goals
        if !context.goalProgress.achieved.isEmpty {
            prompt += "ACHIEVED: \(context.goalProgress.achieved.map { "\($0.stroke ?? "general"): \($0.description)" }.joined(separator: "; ")) → next level\n"
        }
        if !context.goalProgress.struggling.isEmpty {
            prompt += "STRUGGLING: \(context.goalProgress.struggling.map { "\($0.stroke ?? "general"): \($0.description)" }.joined(separator: "; ")) → easier prerequisite\n"
        }
        if context.goalProgress.achieved.isEmpty && context.goalProgress.struggling.isEmpty && context.goalProgress.inProgress.isEmpty {
            prompt += "GOALS: NO ACTIVE GOALS - New swimmer, focus on technique basics first.\n"
        }

        // Settings
        prompt += "SETTINGS: Pool \(context.poolType.fullLabel), \(context.sessionsPerWeek) sessions\n"

        return prompt
    }

    }

// MARK: - Weekly Distance Calculation (Shared)

/// Calculate appropriate weekly total distance based on skill level
/// Based on swimming-interval-training-research.md volume recommendations
private func weeklyDistanceTarget(skillLevel: SkillLevel, sessionsPerWeek: Int, poolType: PoolType) -> Int {
    // Base weekly totals by skill level (in meters)
    let baseWeekly: Int
    switch skillLevel {
    case .beginner:
        baseWeekly = 4000
    case .intermediate:
        baseWeekly = 12000
    case .advanced:
        baseWeekly = 20000
    case .competitive:
        baseWeekly = 30000
    case .elite:
        baseWeekly = 40000
    }

    // Adjust for pool type (LCM = 2x distance for same time)
    let adjusted = poolType == .lcm ? baseWeekly * 2 : baseWeekly

    // Scale by sessions per week (3 sessions is baseline)
    return adjusted * sessionsPerWeek / 3
}

/// Weekly distance based on training tier + sub-tier (more precise)
private func weeklyDistanceTarget(tier: TrainingTier, subTier: SubTier, sessionsPerWeek: Int, poolType: PoolType) -> Int {
    // Base weekly totals from USA Swimming club training structure (in meters)
    let baseWeekly: Int
    switch tier {
    case .preCompetitive:
        switch subTier {
        case .a: baseWeekly = 1500
        case .b: baseWeekly = 3000
        case .c: baseWeekly = 5000
        default: baseWeekly = 3000
        }
    case .bronze:
        switch subTier {
        case .one: baseWeekly = 6000
        case .two: baseWeekly = 10000
        case .three: baseWeekly = 14000
        default: baseWeekly = 8000
        }
    case .silver:
        switch subTier {
        case .one: baseWeekly = 13000
        case .two: baseWeekly = 16000
        case .three: baseWeekly = 21000
        default: baseWeekly = 15000
        }
    case .gold:
        baseWeekly = 32500
    case .senior:
        baseWeekly = 50000
    case .national:
        baseWeekly = 65000
    }

    // Adjust for pool type (LCM = 2x distance for same time)
    let adjusted = poolType == .lcm ? baseWeekly * 2 : baseWeekly

    // Scale by sessions per week (use tier-specific baseline)
    let baselineSessions: Int
    switch tier {
    case .preCompetitive: baselineSessions = 2
    case .bronze: baselineSessions = 3
    case .silver: baselineSessions = 4
    case .gold: baselineSessions = 5
    case .senior: baselineSessions = 6
    case .national: baselineSessions = 8
    }

    return adjusted * sessionsPerWeek / baselineSessions
}

// MARK: - Recovery Strategy

public struct RecoveryStrategy: PlanGenerationStrategy, Sendable {
    public var planType: PlanType { .recovery }

    public func buildSystemRole() -> String {
        return "expert_swimming_coach"
    }

    public func buildUserPrompt(context: PlanContext) -> String {
        return buildBasePrompt(context) + """

        RECOVERY WEEK RULES:
        - LIGHT sessions: 50% normal distance
        - Focus on flexibility, easy drills
        - NO sprint work or high-intensity intervals
        - Extended rest intervals (2x normal)
        - Emphasis on body position and breathing
        - Mental recovery: positive feedback, celebrate recent achievements

        SESSION TYPES: gentle warmup / light drills / easy swim

        JSON OUTPUT (exact types required):
        {
          "overview": {
            "weekFocus": "string - must be 'Active Recovery'",
            "fundamentalRevisitPlan": "string - light fundamental focus"
          },
          "schedule": [{
            "sessionNumber": 1,
            "poolSession": "string - session name like 'Gentle Freestyle'",
            "focus": "string - focus description",
            "sessionType": "string - must be 'recovery'"
          }],
          "detailedSessions": [{
            "sessionNumber": 1,
            "focus": "string - session focus",
            "techniqueFocus": "string - technique emphasis",
            "techniqueFileRef": "string - technique file reference",
            "warmUp": {"distance": "string like '300m'", "drills": ["array of gentle drills"]},
            "drillSet": {"distance": "string like '400m'", "drills": ["array of easy drills"]},
            "mainSet": {"distance": "string like '800m'", "description": "string - easy swim details"},
            "coolDown": {"distance": "string like '200m'"},
            "progressionRationale": "string - recovery rationale"
          }],
          "dryLandProgram": [{
            "exercise": "string - flexibility exercise name",
            "setsReps": "string like '2x10'",
            "techniqueSupport": "string - relaxation benefit"
          }],
          "goalProgressPlan": {
            "continueGoals": ["array - goals to maintain gently"],
            "revisitGoals": ["array - fundamental relaxation goals"]
          },
          "notes": "string - recovery rationale"
        }

        ALL string fields must be actual text, not booleans (except sessionNumber which is Int).
        Generate \(context.sessionsPerWeek) LIGHT sessions. No sprint work. Extended rest.
        OUTPUT ONLY JSON.
        """
    }

    public func guidanceFiles() -> [String] {
        return ["coach_prompt.md"]
    }

    public func coachingRules() -> String {
        return """
        RECOVERY PRINCIPLES:
        - Reduced distance: 50% of normal weekly volume
        - Extended rest: 2x normal rest between sets
        - Focus: flexibility drills, body position awareness
        - Mental: positive reinforcement, no critique
        """
    }

    private func buildBasePrompt(_ context: PlanContext) -> String {
        return MixedTrainingStrategy().buildUserPrompt(context: context)
            .replacingOccurrences(of: "Generate a weekly training plan.", with: "Generate a RECOVERY WEEK training plan.")
    }
}

// MARK: - Endurance Strategy

public struct EnduranceStrategy: PlanGenerationStrategy, Sendable {
    public var planType: PlanType { .endurance }

    public func buildSystemRole() -> String {
        return "expert_swimming_coach"
    }

    public func buildUserPrompt(context: PlanContext) -> String {
        let age = context.profile?.age ?? 16
        let volumeGuidance = ageBasedVolumeGuidance(age: age)

        return buildBasePrompt(context) + """

        ENDURANCE WEEK RULES:
        - Progressive distance building
        - Longer main sets (60%+ of session)
        - Pace-based targets (threshold pace)
        - \(volumeGuidance)
        - Reduced drill sets (15% vs 20%)
        - Include distance per stroke tracking

        SESSION TYPES: distance build / threshold pace / aerobic maintenance

        JSON OUTPUT (exact types required):
        {
          "overview": {
            "weekFocus": "string - must be 'Endurance Building'"
          },
          "schedule": [{
            "sessionNumber": 1,
            "poolSession": "string - session name like 'Distance Builder'",
            "focus": "string - focus description",
            "sessionType": "string - must be 'endurance'"
          }],
          "detailedSessions": [{
            "sessionNumber": 1,
            "focus": "string - session focus",
            "techniqueFocus": "string - technique emphasis",
            "techniqueFileRef": "string - technique file reference",
            "warmUp": {"distance": "string like '600m'"},
            "drillSet": {"distance": "string like '300m'"},
            "mainSet": {"distance": "string like '2000m'", "description": "string - threshold intervals"},
            "coolDown": {"distance": "string like '400m'"},
            "progressionRationale": "string - endurance progression"
          }],
          "dryLandProgram": [{
            "exercise": "string - cardio exercise name",
            "setsReps": "string like '3x20'",
            "techniqueSupport": "string - endurance benefit"
          }],
          "goalProgressPlan": {
            "newGoals": ["array - distance milestone goals"]
          },
          "notes": "string - endurance progression rationale"
        }

        ALL string fields must be actual text, not booleans (except sessionNumber which is Int).
        Generate \(context.sessionsPerWeek) ENDURANCE sessions. Long main sets. Pace targets.
        OUTPUT ONLY JSON.
        """
    }

    public func guidanceFiles() -> [String] {
        return ["coach_prompt.md"]
    }

    public func coachingRules() -> String {
        return """
        ENDURANCE PROGRESSION:
        - Build volume 10% per week (max 20% increase)
        - Threshold pace: sustainable for 30+ min
        - Age <12: max 5,000m/week | 12-15: max 15,000m | 16+: max 40,000m
        """
    }

    private func ageBasedVolumeGuidance(age: Int) -> String {
        if age < 12 {
            return "MAX 5,000m/week - protect young swimmers"
        } else if age < 16 {
            return "MAX 15,000m/week - gradual progression"
        } else {
            return "MAX 40,000m/week - adult endurance training"
        }
    }

    private func buildBasePrompt(_ context: PlanContext) -> String {
        return MixedTrainingStrategy().buildUserPrompt(context: context)
            .replacingOccurrences(of: "Generate a weekly training plan.", with: "Generate an ENDURANCE training plan.")
    }
}

// MARK: - Technique Focus Strategy

public struct TechniqueFocusStrategy: PlanGenerationStrategy, Sendable {
    public var planType: PlanType { .technique }

    public func buildSystemRole() -> String {
        return "expert_swimming_coach"
    }

    public func buildUserPrompt(context: PlanContext) -> String {
        return buildBasePrompt(context) + """

        TECHNIQUE WEEK RULES:
        - LOW intensity, HIGH repetition
        - Extended drill sets (40% vs 20%)
        - Focus on form over speed
        - Shorter main sets (25% vs 50%)
        - Multiple technique file references per session
        - Quality feedback focus

        SESSION TYPES: technique deep-dive / drill intensive / form focus

        JSON OUTPUT (exact types required):
        {
          "overview": {
            "weekFocus": "string - must be 'Technique Mastery'",
            "technicalObjective": "string - technique goal"
          },
          "schedule": [{
            "sessionNumber": 1,
            "poolSession": "string - session name like 'Freestyle Technique Deep-dive'",
            "focus": "string - focus description",
            "sessionType": "string - must be 'technique'"
          }],
          "detailedSessions": [{
            "sessionNumber": 1,
            "focus": "string - session focus",
            "techniqueFocus": "string - technique emphasis",
            "techniqueFileRef": "string - REQUIRED: technique file reference",
            "warmUp": {"distance": "string like '400m'", "drills": ["array of technique warmup drills"]},
            "drillSet": {"distance": "string like '800m'", "drills": ["array - multiple drills from technique file"]},
            "mainSet": {"distance": "string like '500m'", "description": "string - low intensity form focus"},
            "coolDown": {"distance": "string like '300m'"},
            "progressionRationale": "string - technique refinement"
          }],
          "dryLandProgram": [{
            "exercise": "string - technique support exercise",
            "setsReps": "string like '2x15'",
            "techniqueSupport": "string - stroke benefit"
          }],
          "goalProgressPlan": {
            "newGoals": ["array - technique milestone goals"]
          },
          "notes": "string - technique focus rationale"
        }

        ALL string fields must be actual text, not booleans (except sessionNumber which is Int).
        Generate \(context.sessionsPerWeek) TECHNIQUE sessions. 40% drills. Multiple technique refs.
        OUTPUT ONLY JSON.
        """
    }

    public func guidanceFiles() -> [String] {
        return ["coach_prompt.md"]
    }

    public func coachingRules() -> String {
        return """
        TECHNIQUE FOCUS:
        - Drill set: 40% of session (vs normal 20%)
        - Main set: 25% of session (vs normal 50%)
        - Intensity: LOW - focus on perfect form
        - Feedback: detailed, constructive, immediate
        """
    }

    private func buildBasePrompt(_ context: PlanContext) -> String {
        return MixedTrainingStrategy().buildUserPrompt(context: context)
            .replacingOccurrences(of: "Generate a weekly training plan.", with: "Generate a TECHNIQUE-FOCUS training plan.")
    }
}

// MARK: - Dry Land Only Strategy

public struct DryLandOnlyStrategy: PlanGenerationStrategy, Sendable {
    public var planType: PlanType { .dryLandOnly }

    public func buildSystemRole() -> String {
        return "expert_swimming_coach"
    }

    public func buildUserPrompt(context: PlanContext) -> String {
        return buildBasePrompt(context) + """

        DRY LAND ONLY RULES:
        - NO pool sessions in schedule
        - Comprehensive dry-land program
        - Reference {stroke}-dry-land-training.md for exercises
        - Focus: Core (30%), Rotation (20%), Shoulder/Arm (25%), Flexibility (25%)
        - Age-appropriate resistance restrictions

        DRY LAND STRUCTURE:
        - Core: planks, bridges, stability
        - Rotation: medicine ball, cable rotation
        - Shoulder/Arm: bands, light weights (age 16+)
        - Flexibility: dynamic stretches, yoga flow

        JSON OUTPUT (exact types required):
        {
          "overview": {
            "weekFocus": "string - must be 'Dry Land Training'",
            "noPoolSessions": true
          },
          "schedule": [{
            "sessionNumber": 1,
            "poolSession": "string - must be 'Rest' or 'No Pool Session'",
            "dryLand": "string - dry land session name"
          }],
          "detailedSessions": [],
          "dryLandProgram": [
            {
              "exercise": "string - exercise name from dry-land file",
              "setsReps": "string like '3x15'",
              "focus": "string - category like 'Core'",
              "techniqueSupport": "string - which stroke this helps"
            }
          ],
          "goalProgressPlan": {
            "newGoals": ["array - dry-land milestone goals"]
          },
          "notes": "string - dry land rationale"
        }

        ALL string fields must be actual text, not booleans (except sessionNumber and noPoolSessions).

        SELF-REVIEW (CRITICAL - perform before outputting):
        After generating the JSON, verify:
        1. NO POOL SESSIONS: detailedSessions array is empty. All poolSession values are "Rest" or "No Pool Session".
        2. EXERCISE BALANCE: Core ~30%, Rotation ~20%, Shoulder/Arm ~25%, Flexibility ~25%.
        3. AGE RESTRICTIONS: Check swimmer age and verify:
           - Age <12: NO weights, only bodyweight exercises
           - Age 12-15: Light resistance bands only
           - Age 16+: Full program allowed
        4. COMPLETE PROGRAM: Generate at least \(context.sessionsPerWeek * 5) exercises (5+ per session).
        5. JSON VALIDITY: All setsReps are strings like "3x15", not numbers.
           - All exercise names are non-empty strings.
           - All focus categories are valid: Core, Rotation, Shoulder/Arm, Flexibility, Ankle/Kick.

        If any check fails, fix the JSON before outputting.

        Generate \(context.sessionsPerWeek) DRY LAND sessions. NO pool. Full exercise program.
        OUTPUT ONLY JSON (after self-review passes).
        """
    }

    public func guidanceFiles() -> [String] {
        // Return default dry-land files for freestyle - strategy doesn't have access to context
        return ["freestyle-dry-land-training.md"]
    }

    public func coachingRules() -> String {
        return """
        DRY LAND GUIDELINES:
        - Age <12: Bodyweight only
        - Age 12-15: Light resistance bands
        - Age 16+: Progressive resistance training
        - Focus: exercises that directly support swim technique
        """
    }

    private func buildBasePrompt(_ context: PlanContext) -> String {
        var prompt = "Generate a DRY LAND ONLY training week.\n"

        if let profile = context.profile {
            prompt += """
            SWIMMER: \(profile.name), Age \(profile.age), Level \(profile.skillLevel.rawValue)
            STROKES: \(profile.preferredStrokes.map { $0.rawValue }.joined(separator: ", "))

            """
        }

        prompt += """
        DRY LAND CATEGORIES:
        - Core: planks, bridges, stability balls
        - Rotation: medicine ball throws, cable rotations
        - Shoulder/Arm: resistance bands, swim-specific movements
        - Ankle/Kick: ankle flexibility, calf raises
        - Flexibility: dynamic stretches, yoga-inspired

        AGE RESTRICTIONS:
        - Under 12: NO weights, bodyweight exercises only
        - 12-15: Light bands only, NO heavy resistance
        - 16+: Full program including moderate weights

        """

        prompt += "Generate \(context.sessionsPerWeek) dry-land sessions. NO pool workouts.\n"

        return prompt
    }
}

// MARK: - Race Prep Strategy

public struct RacePrepStrategy: PlanGenerationStrategy, Sendable {
    public var planType: PlanType { .racePrep }

    public func buildSystemRole() -> String {
        return "expert_swimming_coach"
    }

    public func buildUserPrompt(context: PlanContext) -> String {
        return buildBasePrompt(context) + """

        RACE PREP WEEK RULES:
        - Race-specific sets (goal pace work)
        - Start/turn practice in each session
        - Taper considerations (reduce volume 20%)
        - Race simulation in final session
        - Mental preparation exercises

        SESSION TYPES: race pace / start/turn focus / taper simulation

        JSON OUTPUT (exact types required):
        {
          "overview": {
            "weekFocus": "string - must be 'Race Preparation'",
            "raceEvent": "string - target race name"
          },
          "schedule": [{
            "sessionNumber": 1,
            "poolSession": "string - session name like 'Race Pace Practice'",
            "focus": "string - focus description",
            "sessionType": "string - must be 'race prep'"
          }],
          "detailedSessions": [{
            "sessionNumber": 1,
            "focus": "string - session focus",
            "techniqueFocus": "string - technique emphasis",
            "techniqueFileRef": "string - technique file reference",
            "warmUp": {"distance": "string - race warmup pattern like '600m'"},
            "drillSet": {"distance": "string like '400m'", "drills": ["array of start/turn drills"]},
            "mainSet": {"distance": "string like '1000m'", "description": "string - goal pace sets"},
            "coolDown": {"distance": "string like '400m'"},
            "raceSimulation": "string - start + turn + pace work details",
            "progressionRationale": "string - race readiness"
          }],
          "dryLandProgram": [{
            "exercise": "string - activation exercise",
            "setsReps": "string like '2x10 light'",
            "techniqueSupport": "string - race prep benefit"
          }],
          "goalProgressPlan": {
            "newGoals": ["array - race time target goals"]
          },
          "notes": "string - race prep rationale"
        }

        ALL string fields must be actual text, not booleans (except sessionNumber which is Int).
        Generate \(context.sessionsPerWeek) RACE PREP sessions. Goal pace work. Start/turn practice.
        OUTPUT ONLY JSON.
        """
    }

    public func guidanceFiles() -> [String] {
        return ["coach_prompt.md"]
    }

    public func coachingRules() -> String {
        return """
        RACE PREP:
        - Taper: reduce volume 20% from normal week
        - Goal pace: use personal bests as reference
        - Starts: practice weekly, timing focus
        - Turns: open/closed turns for race events
        - Mental: visualization, race walkthrough
        """
    }

    private func buildBasePrompt(_ context: PlanContext) -> String {
        return MixedTrainingStrategy().buildUserPrompt(context: context)
            .replacingOccurrences(of: "Generate a weekly training plan.", with: "Generate a RACE PREPARATION training plan.")
    }
}

// MARK: - Speed & Sprint Strategy

public struct SpeedSprintStrategy: PlanGenerationStrategy, Sendable {
    public var planType: PlanType { .speed }

    public func buildSystemRole() -> String {
        return "expert_swimming_coach"
    }

    public func buildUserPrompt(context: PlanContext) -> String {
        return buildBasePrompt(context) + """

        SPEED & SPRINT WEEK RULES:
        - Sprint intervals (25m, 50m bursts)
        - High rest ratios (1:4 work:rest minimum)
        - Pace work: target race pace + overspeed
        - Reaction time drills
        - Maximum effort sets (limited volume)
        - Power-focused dry land

        SESSION TYPES: sprint bursts / pace ladder / power focus

        JSON OUTPUT (exact types required):
        {
          "overview": {
            "weekFocus": "string - must be 'Speed & Sprint'",
            "sprintTarget": "string - sprint goal like 'improve 50m time'"
          },
          "schedule": [{
            "sessionNumber": 1,
            "poolSession": "string - session name like 'Sprint Bursts'",
            "focus": "string - focus description",
            "sessionType": "string - must be 'speed'"
          }],
          "detailedSessions": [{
            "sessionNumber": 1,
            "focus": "string - session focus",
            "techniqueFocus": "string - technique emphasis",
            "techniqueFileRef": "string - technique file reference",
            "warmUp": {"distance": "string like '800m'", "drills": ["array of activation drills"]},
            "drillSet": {"distance": "string like '400m'", "drills": ["array of power drills"]},
            "mainSet": {"distance": "string like '600m'", "description": "string - 25m/50m bursts with high rest"},
            "coolDown": {"distance": "string like '400m'"},
            "sprintRationale": "string - overspeed training explanation",
            "progressionRationale": "string - speed development"
          }],
          "dryLandProgram": [{
            "exercise": "string - power exercise name",
            "setsReps": "string like '3x8 explosive'",
            "techniqueSupport": "string - explosive power benefit"
          }],
          "goalProgressPlan": {
            "newGoals": ["array - sprint time target goals"]
          },
          "notes": "string - speed rationale"
        }

        ALL string fields must be actual text, not booleans (except sessionNumber which is Int).
        Generate \(context.sessionsPerWeek) SPEED sessions. Sprint intervals. High rest ratios.
        OUTPUT ONLY JSON.
        """
    }

    public func guidanceFiles() -> [String] {
        return ["coach_prompt.md"]
    }

    public func coachingRules() -> String {
        return """
        SPRINT TRAINING:
        - Rest ratio: 1:4 minimum (e.g., 25m swim, 100m rest swim)
        - Overspeed: use fins for pace faster than race pace
        - Volume: limited - quality over quantity
        - Power dry land: explosive movements, plyometrics
        """
    }

    private func buildBasePrompt(_ context: PlanContext) -> String {
        return MixedTrainingStrategy().buildUserPrompt(context: context)
            .replacingOccurrences(of: "Generate a weekly training plan.", with: "Generate a SPEED & SPRINT training plan.")
    }
}

// MARK: - Macrocycle Phase Strategies (Silver+ Only)

/// General Preparation Phase (Base Building)
/// Duration: 8-16 weeks
/// Focus: High aerobic volume (60-75% Zone 1-2), threshold introduction (5-10%)
public struct GeneralPrepStrategy: PlanGenerationStrategy, Sendable {
    public var planType: PlanType { .generalPrep }

    public func buildSystemRole() -> String {
        return "expert_swimming_coach"
    }

    public func buildUserPrompt(context: PlanContext) -> String {
        return buildDefaultOutlinePrompt(context, planType: planType) + """

        GENERAL PREPARATION PHASE RULES:
        - Zone distribution: 60-75% Zone 1-2 (aerobic base), 10-15% Zone 3 (tempo), 5-10% Zone 4 (threshold introduction)
        - Long repetitions: 200-500m intervals for aerobic development
        - Long rest relative to work: low metabolic stress, focus on technique consistency
        - High total session volume: building aerobic foundation
        - Primary focus: mitochondrial density, capillary networks, stroke efficiency
        - Volume: highest of all phases, building base for later phases

        CALL read_interval_research(section: "periodization") to get:
        - Zone distribution percentages for Phase 1 (General Preparation)
        - Sample week structures for base building
        - Interval characteristics for this phase

        SESSION TYPES: aerobic base / tempo introduction / technique maintenance

        OUTPUT ONLY JSON.
        """
    }

    public func guidanceFiles() -> [String] {
        return ["coach_prompt.md", "swimming-interval-training-research.md"]
    }

    public func coachingRules() -> String {
        return """
        GENERAL PREP PHASE:
        - Primary: Zone 1-2 aerobic swimming (CSS + 5-15s/100m)
        - Long reps: 200-500m at conversational pace
        - Weekly volume: building toward peak
        - Technique: quality under moderate fatigue
        - NO sprint work in this phase - save neuromuscular reserves
        """
    }
}

/// Specific Preparation Phase (Build Phase)
/// Duration: 6-12 weeks
/// Focus: Threshold work becomes primary (15-25% Zone 4), VO2max introduction (10-15%)
public struct SpecificPrepStrategy: PlanGenerationStrategy, Sendable {
    public var planType: PlanType { .specificPrep }

    public func buildSystemRole() -> String {
        return "expert_swimming_coach"
    }

    public func buildUserPrompt(context: PlanContext) -> String {
        return buildDefaultOutlinePrompt(context, planType: planType) + """

        SPECIFIC PREPARATION PHASE RULES:
        - Zone distribution: 40-50% Zone 1-2 (maintained aerobic), 15-20% Zone 3 (tempo), 15-25% Zone 4 (PRIMARY - threshold), 10-15% Zone 5 (VO2max introduction)
        - Moderate repetitions: 100-300m intervals at threshold
        - Moderate rest: increasing metabolic stress
        - Threshold work is the centerpiece of this phase
        - Primary focus: lactate threshold pace improvement, buffering capacity

        CALL read_interval_research(section: "periodization") to get:
        - Zone distribution percentages for Phase 2 (Specific Preparation)
        - Threshold interval characteristics
        - Sample threshold sets with rest intervals

        SESSION TYPES: threshold main set / tempo bridge / VO2max introduction

        OUTPUT ONLY JSON.
        """
    }

    public func guidanceFiles() -> [String] {
        return ["coach_prompt.md", "swimming-interval-training-research.md"]
    }

    public func coachingRules() -> String {
        return """
        SPECIFIC PREP PHASE:
        - Primary: Zone 4 threshold work (CSS to CSS - 2s/100m)
        - Threshold reps: 100-200m at threshold pace
        - Key sets: 10x100m on tight send-offs
        - Tempo: Zone 3 as bridge work
        - VO2max: limited introduction (10-15%)
        - This is where fitness translates to performance capability
        """
    }
}

/// Pre-Competition Phase (Sharpening)
/// Duration: 4-8 weeks
/// Focus: Race-pace specificity (15-20% Zone 5-6), reduced aerobic volume
public struct PreCompetitionStrategy: PlanGenerationStrategy, Sendable {
    public var planType: PlanType { .preCompetition }

    public func buildSystemRole() -> String {
        return "expert_swimming_coach"
    }

    public func buildUserPrompt(context: PlanContext) -> String {
        return buildDefaultOutlinePrompt(context, planType: planType) + """

        PRE-COMPETITION PHASE RULES:
        - Zone distribution: 25-35% Zone 1-2 (significantly reduced aerobic), 15-20% Zone 3, 15-20% Zone 4, 15-20% Zone 5 (INCREASED VO2max), 10-15% Zone 6 (sprint introduction)
        - Short to moderate repetitions: 25-200m
        - Race-pace specificity increases dramatically
        - Total volume decreases - quality over quantity
        - Primary focus: neuromuscular patterning at race pace, pace awareness

        CALL read_interval_research(section: "periodization") to get:
        - Zone distribution for Phase 3 (Pre-Competition)
        - Race-pace interval design
        - VO2max and sprint integration

        SESSION TYPES: race-pace rehearsal / VO2max sets / sharpening sprints

        OUTPUT ONLY JSON.
        """
    }

    public func guidanceFiles() -> [String] {
        return ["coach_prompt.md", "swimming-interval-training-research.md"]
    }

    public func coachingRules() -> String {
        return """
        PRE-COMPETITION PHASE:
        - Primary: Zone 5 VO2max (CSS - 3-6s/100m) and race-pace work
        - Race-pace reps: exact target race pace
        - Volume: decreasing, intensity increasing
        - Sprint: Zone 6 introduction (10-15%)
        - Focus: quality over quantity
        - Neuromuscular: learning race pace without clock
        """
    }
}

/// Competition Phase (Meet Season)
/// Focus: High sprint/speed (20-30% Zone 6), race-pace precision, low volume
public struct CompetitionPhaseStrategy: PlanGenerationStrategy, Sendable {
    public var planType: PlanType { .competition }

    public func buildSystemRole() -> String {
        return "expert_swimming_coach"
    }

    public func buildUserPrompt(context: PlanContext) -> String {
        return buildDefaultOutlinePrompt(context, planType: planType) + """

        COMPETITION PHASE RULES:
        - Zone distribution: 15-25% Zone 1-2 (maintenance only), 10-15% Zone 3, 10-15% Zone 4, 15-20% Zone 5, 20-30% Zone 6 (PRIMARY - sprint)
        - Very short repetitions: 10-100m
        - Full or near-full recovery between reps
        - Race-pace precision is paramount
        - Low total volume, very high quality
        - Primary focus: meet performance, race readiness, peak speed

        CALL read_interval_research(section: "periodization") to get:
        - Zone distribution for Phase 4 (Competition)
        - Sprint interval design with full recovery
        - Race-pace exactness guidance

        SESSION TYPES: race rehearsal / meet simulation / speed maintenance

        OUTPUT ONLY JSON.
        """
    }

    public func guidanceFiles() -> [String] {
        return ["coach_prompt.md", "swimming-interval-training-research.md"]
    }

    public func coachingRules() -> String {
        return """
        COMPETITION PHASE:
        - Primary: Zone 6 sprint (race pace and faster)
        - Very short reps: 10-50m with full recovery
        - Volume: lowest of all phases
        - Recovery: critical - 10-15% of training
        - Race rehearsal: practice meet routine
        - Intensity maintained, volume minimal
        """
    }
}

/// Taper Phase (10-21 days before major meet)
/// Focus: Volume reduction 41-60%, intensity maintained, race-pace focus (30-40% Zone 6)
public struct TaperStrategy: PlanGenerationStrategy, Sendable {
    public var planType: PlanType { .taper }

    public func buildSystemRole() -> String {
        return "expert_swimming_coach"
    }

    public func buildUserPrompt(context: PlanContext) -> String {
        return buildDefaultOutlinePrompt(context, planType: planType) + """

        TAPER PHASE RULES (10-21 days before major competition):
        - Volume reduction: 41-60% from pre-taper volume
        - Intensity MAINTAINED: race-pace and faster work is maintained or slightly increased
        - Frequency MAINTAINED: training frequency is not significantly reduced (to maintain neuromuscular patterns)
        - Zone distribution Week 1: 30-40% Zone 1-2, 15-20% Zone 5, 20-25% Zone 6
        - Zone distribution Week 2: 20-30% Zone 1-2, 15-20% Zone 5, 25-30% Zone 6
        - Competition Week: 15-20% Zone 1-2, 15-20% Zone 5, 30-40% Zone 6

        CRITICAL: Training load should NOT be reduced at the expense of intensity during taper.
        - Very short, sharp repetitions
        - Race-pace exactness
        - Full recovery between reps
        - Total session distance reduced by 40-60%

        CALL read_interval_research(section: "periodization") to get:
        - Taper protocol from research (Mujika 2010)
        - Zone distribution progression during taper
        - Taper interval characteristics

        SESSION TYPES: race-pace touch-ups / activation sprints / recovery focus

        OUTPUT ONLY JSON.
        """
    }

    public func guidanceFiles() -> [String] {
        return ["coach_prompt.md", "swimming-interval-training-research.md"]
    }

    public func coachingRules() -> String {
        return """
        TAPER PHASE:
        - Volume: reduce 41-60% from pre-taper
        - Intensity: MAINTAIN or increase slightly
        - Frequency: maintain (don't skip sessions)
        - Primary: Zone 6 race-pace work (30-40%)
        - Recovery: 15-20% of training
        - Focus: feeling fast, race-ready
        - Key principle: "Training load should not be reduced at the expense of intensity during the taper"
        """
    }
}