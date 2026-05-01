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

    public var id: String { rawValue }

    public var description: String {
        switch self {
        case .mixed: "Balanced club training"
        case .recovery: "Active recovery, light technique"
        case .endurance: "Distance and stamina building"
        case .technique: "Low intensity, high quality"
        case .dryLandOnly: "No pool sessions"
        case .racePrep: "Competition readiness"
        case .speed: "Sprint and pace work"
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
        }
    }
}

// MARK: - Plan Context

public struct PlanContext: Sendable {
    public let profile: UserProfile?
    public let notes: [TrainingNote]
    public let poolType: PoolType
    public let sessionsPerWeek: Int
    public let includeDryLand: Bool
    public let strokeBalance: [StrokeBalanceInfo]
    public let goalProgress: GoalProgressInfo

    public init(
        profile: UserProfile?,
        notes: [TrainingNote],
        poolType: PoolType,
        sessionsPerWeek: Int,
        includeDryLand: Bool,
        strokeBalance: [StrokeBalanceInfo],
        goalProgress: GoalProgressInfo
    ) {
        self.profile = profile
        self.notes = notes
        self.poolType = poolType
        self.sessionsPerWeek = sessionsPerWeek
        self.includeDryLand = includeDryLand
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
    func guidanceFiles() -> [String]
    func coachingRules() -> String
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
        // Compute weekly total for self-review
        let weeklyTotal = weeklyDistanceTarget(
            skillLevel: context.profile?.skillLevel ?? .intermediate,
            sessionsPerWeek: context.sessionsPerWeek,
            poolType: context.poolType
        )
        let perSessionTarget = weeklyTotal / max(context.sessionsPerWeek, 1)

        return """
        MANDATORY FIRST STEPS (call these tools BEFORE generating the plan):

        1. Call get_css_info() to get the swimmer's Critical Swim Speed (CSS) test results.
           - CSS determines training zone paces (Zone 0-6)
           - Use CSS pace + offsets to set accurate interval targets
           - If no CSS available, use skill level fallback

        2. Call read_interval_research(section: "zones") to understand:
           - Zone definitions and pace targets
           - Volume recommendations by skill level
           - Rest interval guidelines
           - Sample sets for each zone

        3. Call read_interval_research(section: "levels") for swimmer-specific adjustments.

        AFTER reading CSS info and interval research, use that knowledge to:

        STEP 1: DETERMINE SESSION ZONES AND VOLUMES
        - Use CSS zone paces to set main set intensity
        - Match volumes to skill level from research document
        - Zone distribution: 30% Zone 1-2, 40% Zone 3-4, 20% Zone 5, 10% Zone 0

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

        SESSION PLANNING TEMPLATE FORMAT:
        Warm-up: Zone 0-1 (easy, progressive build, 12-20s rest)
        Drill/Pre-set: Zone 1-2 (technique focus, 10-16s rest)
        Main Set: Zone ___ (primary training zone - specify based on session focus)
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
        1. DISTANCE MATH: For EACH segment, calculate sum of (repeatCount × distancePerRep) for all sets.
           - Example: sets=[{"repeatCount":6,"distancePerRep":50},{"repeatCount":4,"distancePerRep":25}]
           - Check: 6×50=300, 4×25=100, total=400m ✓
           - If mismatch found, CORRECT the sets before outputting.
        2. SESSION TOTALS: Each session's segments (warmUp+drillSet+mainSet+secondarySet+coolDown) should total roughly the per-session target.
           - Target: ~\(perSessionTarget)m per session (weekly total divided by \(context.sessionsPerWeek) sessions).
        3. ZONE FIELDS: Each set AND each segment has zone field (Int 0-6):
           - Warm-up sets: zone 0-1
           - Drill/Pre-set sets: zone 1-2
           - Main Set sets: zone based on session focus (3-5 for training, 6 for sprint)
           - Secondary Set sets: zone based on complementary work
           - Cool-down sets: zone 0
        4. SWIM SECONDS / EFFORT: Each set has either swimSeconds OR effort guidance:
           - IF CSS available: swimSeconds = distance × zone pace (e.g., 100m @ Z4 = ~77s)
           - IF no CSS: include effort% in notes (e.g., "85% effort")
        5. REST SECONDS: Each set has restSeconds appropriate for its zone:
           - Zone 0: 60-120s
           - Zone 1: 12-20s
           - Zone 2: 8-16s
           - Zone 3: 8-12s
           - Zone 4: 4-12s
           - Zone 5: 24-40s
           - Zone 6: 180-300s
        6. JSON VALIDITY: All distancePerRep, swimSeconds, restSeconds are Int (not strings).
           - All repeatCount are Int > 0.
           - All zone fields are Int 0-6 (in both sets AND segments).
           - All item fields are non-empty strings.
        7. COMPLETE SESSIONS: Generate exactly \(context.sessionsPerWeek) sessions.
        8. FUNDAMENTALS: At least 30% of sessions include fundamental revisit.

        If any check fails, fix the JSON before outputting the final result.

        Generate \(context.sessionsPerWeek) sessions. Include fundamentals in 30%+ sessions. Match drills to skill tier.
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

        // Weekly total distance guidance based on skill level
        let weeklyTotal = weeklyDistanceTarget(skillLevel: context.profile?.skillLevel ?? .intermediate, sessionsPerWeek: context.sessionsPerWeek, poolType: context.poolType)
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
        if !context.strokeBalance.isEmpty {
            prompt += "STROKE BALANCE (last 14 days):\n"
            for balance in context.strokeBalance {
                prompt += "- \(balance.stroke): \(balance.sessions) sessions (\(balance.percentage)%)\n"
            }
            let neglected = context.strokeBalance.filter { $0.sessions == 0 }.map { $0.stroke }
            if !neglected.isEmpty {
                prompt += "NEGLECTED: \(neglected.joined(separator: ", ")) - include this week\n"
            }
        }

        // Goals
        if !context.goalProgress.achieved.isEmpty {
            prompt += "ACHIEVED: \(context.goalProgress.achieved.map { "\($0.stroke ?? "general"): \($0.description)" }.joined(separator: "; ")) → next level\n"
        }
        if !context.goalProgress.struggling.isEmpty {
            prompt += "STRUGGLING: \(context.goalProgress.struggling.map { "\($0.stroke ?? "general"): \($0.description)" }.joined(separator: "; ")) → easier prerequisite\n"
        }

        // Settings
        prompt += "SETTINGS: Pool \(context.poolType.shortLabel), \(context.sessionsPerWeek) sessions, DryLand \(context.includeDryLand ? "Yes" : "No")\n"

        return prompt
    }

    /// Calculate appropriate weekly total distance based on skill level
    private func weeklyDistanceTarget(skillLevel: SkillLevel, sessionsPerWeek: Int, poolType: PoolType) -> Int {
        // Base weekly totals by skill level (in meters)
        let baseWeekly: Int
        switch skillLevel {
        case .beginner:
            baseWeekly = 1500  // 500m per session for 3 sessions
        case .intermediate:
            baseWeekly = 2200  // ~733m per session for 3 sessions
        case .advanced:
            baseWeekly = 3500  // ~1167m per session for 3 sessions
        case .competitive:
            baseWeekly = 5000  // ~1667m per session for 3 sessions
        case .elite:
            baseWeekly = 8000  // ~2667m per session for 3 sessions
        }

        // Adjust for pool type (long course = 2x distance)
        let adjusted = poolType == .longCourse ? baseWeekly * 2 : baseWeekly

        // Scale by sessions per week (3 sessions is baseline)
        return adjusted * sessionsPerWeek / 3
    }
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