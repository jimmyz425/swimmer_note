import Foundation

public struct MixedTrainingStrategy: PlanGenerationStrategy, Sendable {
    public var planType: PlanType { .mixed }

    public func buildSystemRole() -> String {
        return "expert_swimming_coach"
    }

    public func buildUserPrompt(context: PlanContext) -> String {
        let sessionPlan = context.effectiveWeeklySessionCount
        let weeklyTotal = context.weeklyPoolVolumeTargetMeters
        let perSessionTarget = context.perSessionPoolVolumeTargetMeters
        let perSessionDivisor = context.perSessionPoolVolumePlanningDivisor

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
        - Distance set: {"repeatCount": N, "distancePerRep": M, "swimSeconds": S, "item": "description", "equipment": "none or gear from drill table", "notes": "coaching notes from drill table", "zone": Z, "restSeconds": R}
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
        Drill/Pre-set: Zone 1-2 (technique focus, 10-16s rest) — use get_technique_drills (classic drills)
        Main Set: Zone ___ (primary training zone - specify based on session focus AND TIER ALLOWANCE)
        Secondary Set (optional): read_evidence_drills when coaching style calls for exploration — one code, one JSON set per table row; omit when not appropriate
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
            "secondarySet": {"sets": [{"repeatCount": 2, "distancePerRep": 25, "swimSeconds": 40, "item": "Easy backstroke", "equipment": "none", "notes": "CSS + 10-15s/100m", "zone": 1, "restSeconds": 15}, {"repeatCount": 8, "distancePerRep": 25, "swimSeconds": 38, "item": "Build stroke rate each 25m", "equipment": "tempo trainer", "notes": "+2-4 BPM per rep", "zone": 3, "restSeconds": 20}, {"repeatCount": 1, "distancePerRep": 100, "swimSeconds": 115, "item": "Easy recovery", "equipment": "none", "notes": "CSS + 20-30s/100m", "zone": 0, "restSeconds": 0}], "zone": 2},
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
        Include "secondarySet" only when user coaching styles or session focus benefit from evidence-based exploration (read_evidence_drills). When present: one drill code, one set per table row, equipment + notes from table.
        Use read_coach_reference for drillSet/mainSet structure from selected coaching styles.
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
           - Target: ~\(perSessionTarget)m per session (weekly \(weeklyTotal)m ÷ \(perSessionDivisor); divisor = max(\(sessionPlan) session(s), tier max practices/week) so fewer days does not inflate per-practice volume).
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
        9. COMPLETE SESSIONS: Generate exactly \(sessionPlan) sessions.
        10. FUNDAMENTALS: At least 30% of sessions include fundamental revisit.
        11. SECONDARY SET: If secondarySet is present, verify it is one evidence drill code only, sets align with that drill's table (no get_technique_drills content such as 6-3-6 unless it is literally a row in the chosen evidence drill), no multi-drill prose in a single item field, and each set includes equipment + notes from the table (app UI shows these per rep).

        If any check fails, fix the JSON before outputting the final result.

        Generate \(sessionPlan) sessions. Include fundamentals in 30%+ sessions. Match drills to skill tier.
        USE TIER GUIDANCE for zone distribution and session volumes.
        USE CSS ZONE PACES for interval targets when CSS is available.
        OUTPUT ONLY JSON (after self-review passes).
        """
    }

    public func guidanceFiles() -> [String] {
        return ["coach_prompt.md", "swimming-coach-role-reference.md", "swimming-interval-training-research.md"]
    }

    public func coachingRules() -> String {
        return """
        SESSION BALANCE: 30% fundamentals, 50% current-level, 20% stretch.
        Honor user-selected coaching styles from swimming-coach-role-reference.md (embedded in context).
        For drillSet: get_technique_drills and/or signature sets from read_coach_reference — match active coaching style(s).
        For mainSet: structure from coaching style (Reese pace work, Bowman negatives, Salo SR sets, playful youth games, etc.).
        For secondarySet: optional — read_evidence_drills when style/session needs exploration block; omit otherwise.
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

        let sessionPlan = context.effectiveWeeklySessionCount
        let weeklyTotal = context.weeklyPoolVolumeTargetMeters
        let volDivisor = context.perSessionPoolVolumePlanningDivisor
        let perSessionFromPlanning = context.perSessionPoolVolumeTargetMeters
        prompt += """
        WEEKLY TOTAL DISTANCE: \(weeklyTotal) across ALL sessions combined.
        Each session should be roughly \(perSessionFromPlanning)m (weekly ÷ \(volDivisor); divisor is max of your \(sessionPlan) session(s) and the tier’s high-end practices/week so per-session load stays steady if you miss a day).

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
        #if DEBUG
        prompt += "SETTINGS: Pool \(context.poolType.fullLabel), \(sessionPlan) sessions [debug: PlanContext.sessionsPerWeek=\(context.sessionsPerWeek) profile.weeklySessionTarget=\(context.profile?.weeklySessionTarget ?? -1)]\n"
        #else
        prompt += "SETTINGS: Pool \(context.poolType.fullLabel), \(sessionPlan) sessions\n"
        #endif

        return prompt
    }

    }
