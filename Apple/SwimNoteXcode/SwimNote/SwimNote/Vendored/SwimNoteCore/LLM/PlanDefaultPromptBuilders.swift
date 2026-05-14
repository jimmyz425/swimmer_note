import Foundation

// MARK: - Phase 1: Outline Prompt Builder

/// Build default Phase 1 outline prompt with pre-gathered data
internal func buildDefaultOutlinePrompt(_ context: PlanContext, planType: PlanType) -> String {
    // Check if this is a macrocycle phase (requires interval training research reference)
    let isMacrocyclePhase = planType.requiresAdvancedTier

    var prompt = """
    You are a professional swim coach preparing a weekly training plan for \(planType.rawValue).

    You have all the context you need below: swimmer profile, past training sessions with technique details, and USA Swimming tier guidance. Review everything carefully before responding.

    ---

    TOOL CALLS (do these first):

    1. Call read_usa_swimming_structure(section: "all") to get comprehensive tier background:
       - Quick-Reference Summary Table with all tier definitions
       - Zone distribution percentages per tier and sub-tier
       - Volume progression (weekly/per-session distances in km)
       - Practices per week recommendations by tier
       - Sub-tier breakdowns with detailed criteria
       - Training focus allocation by tier

       Use this to determine sessions/week, weekly distance, per-session targets, and zone distribution.

    2. Call get_tier_guidance() to get specific guidance for the swimmer's current tier/sub-tier.

    """

    // Add macrocycle phase-specific tool call
    if isMacrocyclePhase {
        prompt += """
    3. CRITICAL FOR MACROCYCLE PHASE: Call read_interval_research(section: "periodization") to get:
       - Detailed zone distribution percentages for this specific phase
       - Interval characteristics (distance, rest patterns) for the phase
       - Sample week structures for each macrocycle phase

    """
    }

    if let profile = context.profile {
        prompt += """
        SWIMMER PROFILE:
        - Name: \(profile.name), Age: \(profile.age)
        - Training Tier: \(profile.trainingTier.displayName) (\(profile.trainingTier.fullName))
        - Sub-Tier: \(profile.subTier.displayName)

        Pool Type: \(context.poolType.fullLabel)
        Pool length: \(Int(context.poolType.poolLengthMeters))\(context.poolType == .scy ? "yd" : "m"). Adjust distance targets accordingly.

        """
    } else {
        prompt += """
        SWIMMER PROFILE:
        - Training Level: Intermediate (Silver / Age Group)
        - No specific profile set - use Silver 1 defaults

        Pool Type: \(context.poolType.fullLabel)

        """
    }

    // Past training data
    if !context.pastSessions.isEmpty {
        prompt += """
        PAST TRAINING SESSIONS (\(context.pastSessions.count) sessions from the past 2 weeks):
        \(context.pastSessions.joined(separator: "\n"))

        """

        if !context.pastTechniqueSections.isEmpty {
            prompt += """
            TECHNIQUE DETAILS COVERED (key focus points and common mistakes from each technique file used in past sessions):
            \(context.pastTechniqueSections.joined(separator: "\n\n"))

            """
        }
    } else {
        prompt += """
        NO PAST PLANS — This is a new swimmer. Focus on technique fundamentals and gradual volume introduction.

        """
    }

    prompt += """
    ————————————————————————————————————————————————

    YOUR ROLE: Write like a professional swim coach. Review all the data above — sessions, technique content, tier guidance — and produce three things in order:

    ## PART 1: COACHING SUMMARY (the "State of the Swimmer")

    Produce a clear, narrative summary of where this swimmer has been over the past 2 weeks. Write in plain English — like you're explaining it to the swimmer or their parent at a pool-side check-in. Include:

    - **Volume & consistency** — How many sessions were planned, were they spread well across the week?
    - **Stroke balance** — Which strokes got attention, which were neglected?
    - **Technique progression** — Look at the technique details above. What specific skills were worked on? What level (body position → arm entry → catch → pull) is each stroke currently at? What's the natural next step for each stroke?
    - **What needs revisiting** — Identify any fundamentals from 2+ weeks ago that should recur (e.g., body position always needs periodic reinforcement).
    - **Goal progress** — Any active or achieved goals from recent logs.

    If there are no past sessions, state this is a fresh start and outline what the first week should focus on.

    ## PART 2: WEEK PREVIEW (the "What's Coming")

    Before generating the JSON schedule, write a forward-looking preview of what this week's plan will accomplish and why. This should:

    - Explain the weekly focus in coaching terms
    - Reference specific past techniques this week builds on (e.g., "Now that freestyle body position and breathing are established, we introduce body rotation and early arm entry")
    - Note which fundamentals will be revisited
    - Explain the session structure rationale (why these strokes on these days)
    - Address any neglected strokes and how they'll be reintroduced

    ## PART 3: WEEKLY PLAN (JSON)

    Generate the outline in the JSON format below. Each session must have:

    - Session count from tier guidance (practices_per_week), NOT arbitrary selection
    - Weekly distance aligned with tier's weekly_distance range
    - Per-session distance aligned with tier's per_session_distance range
    - Zone distribution matching tier's percentages
    - Technique focus that progresses from what was covered before (see your Coaching Summary above)
    - At least one REVISIT session if past training exists
    - A neglected stroke session if applicable

    ```
    {
      "tierGuidance": {
        "tier": "string",
        "subTier": "string",
        "sessionsPerWeek": "int",
        "weeklyDistanceTarget": "int - meters",
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
      "twoWeekSummary": {
        "totalSessions": "int",
        "strokeDistribution": {
          "freestyle": "int",
          "backstroke": "int",
          "breaststroke": "int",
          "butterfly": "int"
        },
        "neglectedStrokes": ["array of stroke names"],
        "goalProgress": "string - goal status from logs",
        "keyTrends": "string - patterns (e.g., 'freestyle heavy, no butterfly')",
        "techniqueProgression": "string - where each stroke is technically and what level comes next",
        "coveredTechniques": "string - specific focus points and mistakes covered (e.g., 'freestyle body position: look down, hips high. freestyle breathing: bilateral, avoid lifting head')"
      },
      "pastTrainingSummary": "string - the COACHING SUMMARY from Part 1 above — plain English narrative",
      "planConnectionRationale": "string - the WEEK PREVIEW from Part 2 above — forward-looking plan rationale",
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
          "estimatedDuration": "string - practice duration",
          "estimatedDistance": "string - distance"
        }
      ],
      "notes": "string - weekly coaching rationale"
    }
    ```

    IMPORTANT:
    - Output ONLY the JSON — no explanations before or after
    - The pastTrainingSummary and planConnectionRationale fields should contain the full narrative text from Parts 1 and 2
    - techniqueFileRef should reference specific technique files that match the session's focus (e.g., "freestyle-05-arm-entry" for an arm entry session)
    """
    return prompt
}

// MARK: - Phase 2: Detail Prompt Builder

/// Build default Phase 2 detail prompt for pool sessions (no dryland)
internal func buildDefaultDetailPrompt(_ sessionOutline: SessionOutline, weeklyOutline: WeeklyPlanOutline, context: PlanContext) -> String {
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

    let pastSummary = weeklyOutline.pastTrainingSummary ?? "No past training history available."
    let planRationale = weeklyOutline.planConnectionRationale ?? ""
    let coveredTech = weeklyOutline.twoWeekSummary?.coveredTechniques ?? ""
    let techniqueProg = weeklyOutline.twoWeekSummary?.techniqueProgression ?? ""

    let prompt = """
    Generate PHASE 2 DETAILED SESSION for session #\(sessionOutline.sessionNumber).

    PAST TRAINING: \(pastSummary)
    PLAN RATIONALE: \(planRationale)

    PAST TECHNIQUE COVERAGE (from Phase 1 summary):
    \(coveredTech.isEmpty ? "No previous technique content to reference." : coveredTech)
    \(techniqueProg.isEmpty ? "" : "TECHNIQUE PROGRESSION ANALYSIS: " + techniqueProg)

    SESSION CONTEXT:
    - Session focus: \(sessionOutline.poolSession) - \(sessionOutline.focus)
    - Technique focus: \(sessionOutline.techniqueFocus ?? "general")
    - Estimated distance: \(sessionOutline.estimatedDistance ?? "~3000m")
    - Primary stroke: \(primaryStroke)

    SWIMMER CONTEXT:
    - Skill Level: \(skillLevel)
    - Pool Type: \(context.poolType.fullLabel)
    - CSS Pace: \(cssPace)/100m

    MANDATORY — Evidence-Based Secondary Drill Set (stroke-evidence-based-drills.md ONLY):
    1. Call read_evidence_drills(stroke="\(primaryStroke)") to list codes (F1, F2, …).
    2. Pick exactly ONE code that matches this session's focus, then call read_evidence_drills(stroke="\(primaryStroke)", drill="<CODE>") for the full set table and level adjustments.
    3. Build secondarySet ONLY from that returned text. Do not use get_technique_drills or classic stroke drills (e.g. 6-3-6, catch-up, single-arm) here unless they appear verbatim as a row in that evidence drill table.
    4. STRUCTURE: secondarySet.sets must be a list of separate objects — typically one JSON set per table row (# column). Each set's repeatCount × distancePerRep must match that row's Reps × Distance. Map columns: **item** = Description, **equipment** = Equipment (use "none" when the table says none), **notes** = Notes (verbatim from the table). Do not merge rows or omit equipment/notes for secondary sets.
    5. Include the evidence citation from the tool result in sessionNotes.

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
          {"repeatCount": 2, "distancePerRep": 25, "swimSeconds": 40, "item": "Easy swim at comfortable stroke rate", "equipment": "none", "notes": "CSS + 10-15s/100m; loose, relaxed", "zone": 1, "restSeconds": 15},
          {"repeatCount": 8, "distancePerRep": 25, "swimSeconds": 35, "item": "Build stroke rate progressively each 25m", "equipment": "tempo trainer", "notes": "Start Z3 (CSS pace); end Z6 (race pace); +2-4 BPM per rep", "zone": 3, "restSeconds": 20},
          {"repeatCount": 1, "distancePerRep": 100, "swimSeconds": 120, "item": "Easy, focus on technique", "equipment": "none", "notes": "CSS + 20-30s/100m", "zone": 0, "restSeconds": 0}
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
internal func buildDefaultDryLandPrompt(_ outline: WeeklyPlanOutline, context: PlanContext) -> String {
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

    let drylandPastSummary = outline.pastTrainingSummary ?? "No past training history available."

    let prompt = """
    Generate DRY LAND EXERCISES to complement this week's swimming training plan.

    PAST TRAINING: \(drylandPastSummary)

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
internal func buildTierDescription(_ tier: TrainingTier, _ subTier: SubTier) -> String {
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
internal struct TierInfo {
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
internal func getTierInfo(_ tier: TrainingTier) -> TierInfo {
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
internal func getSubTierInfo(_ subTier: SubTier, _ tier: TrainingTier) -> String {
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
