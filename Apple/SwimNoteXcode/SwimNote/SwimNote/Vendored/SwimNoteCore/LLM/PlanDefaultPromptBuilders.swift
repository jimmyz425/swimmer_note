import Foundation

// MARK: - Phase 1: Outline Prompt Builder

/// Build default Phase 1 outline prompt with pre-gathered data
internal func buildDefaultOutlinePrompt(_ context: PlanContext, planType: PlanType) -> String {
    var prompt = """
    You are a professional swim coach preparing a weekly training plan for \(planType.rawValue).

    You have all the context you need below: swimmer profile, embedded tier guidance (speed level and zone mix), past training sessions with technique details, and app volume targets. Review everything carefully before responding. Do not call tools — all tier and volume data is embedded.

    ---

    \(context.embeddedTierGuidance)

    \(context.embeddedCoachingStyleGuidance)

    ---

    """

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

    let weeklyPoolM = context.weeklyPoolVolumeTargetMeters
    let planSessions = context.effectiveWeeklySessionCount
    let perSessionDiv = context.perSessionPoolVolumePlanningDivisor
    let perSessionPoolM = context.perSessionPoolVolumeTargetMeters
    prompt += """
    APP VOLUME TARGETS (use these exact numbers in JSON `tierGuidance` and each session’s `estimatedDistance`):
    - `tierGuidance.weeklyDistanceTarget`: \(weeklyPoolM) (meters, all pool sessions this week combined)
    - `tierGuidance.sessionsPerWeek`: \(planSessions)
    - `tierGuidance.perSessionTarget`: \(perSessionPoolM) (meters; \(weeklyPoolM) ÷ \(perSessionDiv), where divisor = max(\(planSessions), tier’s high-end practices/week) so fewer swim days do not push per-practice meters up)
    - Schedule: aim for \(planSessions) pool sessions in `schedule`; total swim volume across the week should approximate \(weeklyPoolM) meters.

    PER-SESSION DISTANCE vs DURATION:
    - Target the **upper end** of each tier's typical duration range to allow adequate coaching time.
    - Silver 1: aim for 75 min (range 60-75). At ~50-60 m/min active swim time, ~60 min active → ~3,000-3,600m.
    - Silver 2-3: aim for 90 min. At ~50-65 m/min active, ~70 min active → ~3,500-4,500m.
    - Bronze: aim for 75 min (range 45-75).
    - Gold: aim for 120 min (range 90-120).
    - Senior: aim for 150 min (range 90-150).
    - Pre-Comp: aim for 60 min (range 30-60).
    - National: aim for 180 min (range 120-180).
    - `estimatedDuration` should reflect total pool time (warm-up through cool-down, including rest, instruction, and coaching time).

    """

    prompt += """
    ————————————————————————————————————————————————

    YOUR ROLE: Write like a professional swim coach. Before generating JSON, reason through the following steps mentally:

    STEP 1 — PROFILE ANALYSIS:
    - Identify tier, sub-tier, and skill level from the embedded guidance
    - Check CSS pace and personal bests for intensity calibration
    - Note pool type (SCM/SCY) for distance scaling

    STEP 2 — PAST SESSION REVIEW:
    - For each past session: what was the focus? what zones? which strokes?
    - Identify technique continuity: what was covered, what comes next naturally?
    - Spot neglected strokes or gaps in zone distribution
    - Note recurring technique fundamentals that need periodic reinforcement

    STEP 3 — ZONE DISTRIBUTION:
    - Use the embedded tier guidance zone distribution as your baseline
    - Adjust based on plan type: Mixed = balanced, Recovery = Z0-Z2 heavy, Race Prep = Z4-Z6 heavy
    - For sub-tiers: sprint = more Z5-Z6, distance = more Z1-Z2

    STEP 4 — SLOT TEMPLATE PER SESSION:
    For each session, decide which of the 10 canonical slots (A-H) to activate:
    - REQUIRED: A (warm-up), E1 (main set 1), H (cool-down)
    - USUALLY: C1 (drill block 1)
    - OPTIONAL based on session type and tier:
      B (activation): Gold+ nearly always; Pre-Comp merge into warm-up
      C2 (drill block 2): when two technique focuses are needed
      D (kick set): **used by all tiers** — flutter kick, dolphin kick, kick on back, kick no board, mixed kick, speed kick, or skip
      E2 (main set 2): Gold+ when dual stimulus needed
      F (speed/race skills): sprint sessions, race prep, Gold+
      G (pull set): upper-body endurance, aerobic without legs
    - Pre-Competitive minimal: A, C1, E1, H
    - Gold+ typical: A, B, C1, C2, D, E1, E2, F, H (8-10 slots)
    - Before picking slot options, call read_session_template(section="options") to see the full option catalog with D1-D7 kick set options.
    - For each active slot, select a slot option ID from the session template system:
      A: A1 (easy choice), A2 (structured), A3 (dynamic+swim), A4 (meet warm-up), A5 (sculling), A6 (game-based)
      B: B1 (build swims), B2 (stroke-specific build), B3 (perfect rep), B4 (speed ramp), B5 (underwater), B6 (skip)
      C1: C1a (freestyle), C1b (backstroke), C1c (breaststroke), C1d (butterfly), C1e (mixed), C1f (underwater), C1g (sculling), C1h (skill stations)
      C2: C2a (different stroke), C2b (starts/turns), C2c (contrast drill), C2d (differential learning), C2e (video/feedback), C2f (skip)
      D: D1 (flutter kick), D2 (dolphin kick), D3 (kick on back), D4 (kick no board), D5 (mixed kick), D6 (speed kick), D7 (skip)
      E1: E1a (aerobic base), E1b (all-four-stroke), E1c (IM development), E1d (threshold), E1e (distance per stroke), E1f (negative-split), E1g (broken swims), E1h (race-pace intervals), E1i (playful/exploratory), E1j (technique under fatigue), E1k (speed play)
      E2: E2a (speed endurance), E2b (sprint set), E2c (lactate tolerance), E2d (IM speed), E2e (supra-race-pace), E2f (contrast set), E2g (pull set as E2), E2h (game/relay), E2i (skip)
      F: F1 (start practice), F2 (turn practice), F3 (sprint from dive), F4 (underwater isolation), F5 (15-meter wars), F6 (race rehearsal), F7 (relay takeovers), F8 (skip)
      G: G1 (steady pull), G2 (pull build), G3 (pull with parachute), G4 (pull scull mix), G5 (skip)

    STEP 5 — TECHNIQUE CONTINUITY:
    - Map past technique files to current session needs
    - Ensure progressive difficulty (don't skip levels in technique progression)
    - Plan at least one REVISIT session per week if past training exists

    ————————————————————————————————————————————————

    Generate the outline in the JSON format below. Each session must have:

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
          "estimatedDuration": "string - practice duration, e.g. ~60min",
          "estimatedDistance": "string - distance, e.g. ~3000m",
          "slotTemplate": ["array of active slot IDs, e.g. A, B, C1, E1, H"],
          "slotOptionIds": {"object mapping slot ID to option, e.g. {\"C1\": \"C1a\", \"E1\": \"E1h\"}"},
          "techniqueContinuity": "string - how this session builds on past technique work"
        }
      ],
      "notes": "string - weekly coaching rationale"
    }
    ```

    IMPORTANT:
    - Output ONLY a single JSON object — no markdown fences, no text before or after
    - Put the full Part 1 narrative in `pastTrainingSummary` and Part 2 in `planConnectionRationale` only
    - `tierGuidance.zoneDistribution` must match the embedded DETAILED ZONE DISTRIBUTION (zone0–zone6)
    - `tierGuidance` weeklyDistanceTarget, sessionsPerWeek, and perSessionTarget must match APP VOLUME TARGETS exactly
    - techniqueFileRef must be a JSON **string** in double quotes (e.g., "freestyle-05-arm-entry"), never a bare number; use a slug that matches the session focus or null if unsure
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

    let pacingGuidance = PlanTierGuidancePrompt.phase2PacingGuidance(for: context)

    let prompt = """
    Generate PHASE 2 DETAILED SESSION for session #\(sessionOutline.sessionNumber).

    PAST TRAINING: \(pastSummary)
    PLAN RATIONALE: \(planRationale)

    PAST TECHNIQUE COVERAGE (from Phase 1 summary):
    \(coveredTech.isEmpty ? "No previous technique content to reference." : coveredTech)
    \(techniqueProg.isEmpty ? "" : "TECHNIQUE PROGRESSION ANALYSIS: " + techniqueProg)

    \(context.embeddedTierGuidance)

    \(context.embeddedCoachingStyleGuidance)

    PACING (read before building sets):
    \(pacingGuidance)

    SESSION CONTEXT:
    - Session focus: \(sessionOutline.poolSession) - \(sessionOutline.focus)
    - Technique focus: \(sessionOutline.techniqueFocus ?? "general")
    - Estimated distance (outline): \(sessionOutline.estimatedDistance ?? "not specified — use app per-session target below")
    - Primary stroke: \(primaryStroke)

    POOL METERS (Phase 2): Aim for total swim distance (sum of repeatCount×distancePerRep in all segments with distancePerRep) within ~15% of the outline’s `estimatedDistance`, or ~\(context.perSessionPoolVolumeTargetMeters)m if the outline string is vague. Weekly plan context: \(context.weeklyPoolVolumeTargetMeters)m/week across \(context.effectiveWeeklySessionCount) sessions.

    SWIMMER CONTEXT:
    - Skill Level: \(skillLevel)
    - Pool Type: \(context.poolType.fullLabel)
    - CSS Pace: \(cssPace)/100m

    COACHING & SET DESIGN:
    1. Honor user-selected coaching styles above. Call read_coach_reference(tier="\(context.profile?.trainingTier.rawValue ?? "silver")") when you need Use/Avoid lists or signature sets for this session.
    2. drillSet: get_technique_drills for stroke technique work and/or signature sets from the coach reference — match the active style(s), not a generic drill list. Set slotId="C1" and if using an evidence drill, set evidenceDrillCode (e.g. "F1").
    3. mainSet: primary block aligned with style. Set slotId="E1". Use embedded tier zones for intensity.
    4. Optional slots: When the session's outline slotTemplate includes B, C2, D, E2, F, or G, generate the corresponding segment:
       - activation (slotId="B"): bridge warm-up to main work; options B1-B6
       - secondarySet (slotId="C2"): second drill block or exploration set
       - kickSet (slotId="D"): leg strength or kick technique; use D1-D7 options (flutter, dolphin, on back, no board, mixed, speed, skip)
       - mainSet2 (slotId="E2"): secondary training stimulus
       - speedSkills (slotId="F"): max velocity, starts, turns, breakouts
       - pullSet (slotId="G"): upper-body endurance, stroke feel
       Call read_session_template(section="options") if you need the full slot option catalog.
    5. secondarySet: OPTIONAL evidence/exploration block. If used: read_evidence_drills(stroke="\(primaryStroke)") → pick ONE code → read_evidence_drills(stroke="\(primaryStroke)", drill="<CODE>") → one JSON set per table row with item/equipment/notes from the table. Set evidenceDrillCode on the segment. Omit entirely when styles don't call for it.
    6. For every segment, set the slotId field to the canonical slot (A, B, C1, C2, D, E1, E2, F, G, H). Set slotOptionId on individual SetItems when referencing the option catalog.
    7. sessionNotes: cite coaching style rationale and any evidence drill source when secondarySet is present.

    OUTPUT JSON FORMAT (detailed session with sets):
    {
      "sessionNumber": \(sessionOutline.sessionNumber),
      "focus": "\(sessionOutline.focus)",
      "techniqueFocus": "\(sessionOutline.techniqueFocus ?? "general")",
      "activeSlots": ["array of active slot IDs for this session"],
      "warmUp": {
        "slotId": "A",
        "sets": [
          {"repeatCount": 4, "distancePerRep": 100, "swimSeconds": 120, "item": "easy freestyle", "zone": 1, "restSeconds": 15}
        ],
        "zone": 1
      },
      "drillSet": {
        "slotId": "C1",
        "sets": [
          {"repeatCount": 3, "distancePerRep": 50, "swimSeconds": 60, "item": "drill", "zone": 2, "restSeconds": 12}
        ],
        "zone": 2
      },
      "mainSet": {
        "slotId": "E1",
        "sets": [
          {"repeatCount": 8, "distancePerRep": 100, "swimSeconds": 85, "item": "freestyle tempo", "zone": 3, "restSeconds": 10}
        ],
        "zone": 3
      },
      "coolDown": {
        "slotId": "H",
        "sets": [
          {"repeatCount": 2, "distancePerRep": 100, "swimSeconds": 120, "item": "easy mixed", "zone": 0, "restSeconds": 30}
        ],
        "zone": 0
      },
      "secondarySet": {
        "slotId": "C2",
        "sets": [
          {"repeatCount": 2, "distancePerRep": 25, "swimSeconds": 40, "item": "Easy swim at comfortable stroke rate", "equipment": "none", "notes": "CSS + 10-15s/100m; loose, relaxed", "zone": 1, "restSeconds": 15},
          {"repeatCount": 8, "distancePerRep": 25, "swimSeconds": 35, "item": "Build stroke rate progressively each 25m", "equipment": "tempo trainer", "notes": "Start Z3 (CSS pace); end Z6 (race pace); +2-4 BPM per rep", "zone": 3, "restSeconds": 20},
          {"repeatCount": 1, "distancePerRep": 100, "swimSeconds": 120, "item": "Easy, focus on technique", "equipment": "none", "notes": "CSS + 20-30s/100m", "zone": 0, "restSeconds": 0}
        ],
        "zone": 2
      },
      "activation": {
        "slotId": "B",
        "sets": [{"repeatCount": 4, "distancePerRep": 25, "swimSeconds": 30, "item": "build each 25", "zone": 2, "restSeconds": 10}],
        "zone": 2
      },
      "kickSet": {
        "slotId": "D",
        "sets": [{"repeatCount": 6, "distancePerRep": 50, "swimSeconds": 60, "item": "kick with board", "equipment": "board", "zone": 2, "restSeconds": 15}],
        "zone": 2
      },
      "mainSet2": {
        "slotId": "E2",
        "sets": [{"repeatCount": 4, "distancePerRep": 100, "swimSeconds": 85, "item": "threshold pace", "zone": 4, "restSeconds": 15}],
        "zone": 4
      },
      "speedSkills": {
        "slotId": "F",
        "sets": [{"repeatCount": 8, "distancePerRep": 25, "swimSeconds": 15, "item": "race pace sprint", "zone": 5, "restSeconds": 45}],
        "zone": 5
      },
      "pullSet": {
        "slotId": "G",
        "sets": [{"repeatCount": 4, "distancePerRep": 100, "swimSeconds": 90, "item": "pull with buoy", "equipment": "pull buoy", "zone": 2, "restSeconds": 15}],
        "zone": 2
      },
      "sessionNotes": "string - coaching tips for this session, include evidence-based drill source",
      "progressionRationale": "string - why this progression"
    }

    RULES:
    - warmUp, drillSet, mainSet, and coolDown are ALWAYS required
    - activation, kickSet, mainSet2, secondarySet, speedSkills, and pullSet are OPTIONAL — include only when the session's slotTemplate lists the corresponding slot
    - Set slotId on every segment to match the canonical slot
    - Set evidenceDrillCode on drillSet when using an evidence-based drill (F1-F5, B1-B5, BR1-BR5, FL1-FL5)
    - Set slotOptionId on individual SetItems when referencing the option catalog (C1a, E1h, etc.)
    - Set equipment to "none" or omit when no equipment is used

    OUTPUT ONLY JSON (no explanations).
    """

    return prompt
}

// MARK: - Phase 3: Dry Land Prompt Builder

/// Build default Phase 3 prompt for weekly dryland based on full plan
internal func buildDefaultDryLandPrompt(_ outline: WeeklyPlanOutline, context: PlanContext) -> String {
    // Summarize the week's technique focuses
    let techniqueFocuses = outline.schedule.compactMap { $0.techniqueFocus }.joined(separator: ", ")
    let strokeList = DryLandExerciseCatalog.strokesFromWeeklyOutline(outline)
    let uniqueStrokes = strokeList.joined(separator: ", ")
    let allowedExercises = DryLandExerciseCatalog.allowedExercisesPromptSection(strokes: strokeList)

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

    \(context.embeddedTierGuidance)

    \(allowedExercises)

    DRY LAND REQUIREMENTS:
    1. Generate 5-7 exercises that complement the pool training
    2. Target areas based on technique focuses: Core stability, Rotation power, Shoulder strength, Flexibility
    3. Match exercises to swimmer's skill level
    4. Use exerciseId values ONLY from ALLOWED DRY LAND EXERCISES above (e.g., "plank-hold"). Do not invent IDs.

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
    - Return exerciseId (NOT exercise name) — must match an id from ALLOWED DRY LAND EXERCISES (e.g., "plank-hold")
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
            practiceDuration: "30-60 min",
            weeklyDistance: "3-8 km (3,000-8,000m)",
            perSessionTarget: "1,000-2,500m",
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
            practiceDuration: "45-75 min",
            weeklyDistance: "8-18 km (8,000-18,000m)",
            perSessionTarget: "2,000-4,500m",
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
            practiceDuration: "60-90 min",
            weeklyDistance: "15-28 km (15,000-28,000m)",
            perSessionTarget: "3,000-6,000m",
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
            practiceDuration: "90-120 min",
            weeklyDistance: "25-40 km (25,000-40,000m)",
            perSessionTarget: "5,000-8,000m",
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
            practiceDuration: "90-150 min",
            weeklyDistance: "40-60 km (40,000-60,000m)",
            perSessionTarget: "6,000-9,000m",
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
    case .one:
        return "1 - Entry level in this tier, building volume and skills for the group"
    case .two:
        return "2 - Mid-level, comfortable with tier expectations, steady improvement"
    case .three:
        return "3 - Top of tier, ready for next group, meeting time standards"
    case .sprint:
        return "Sprint - 50–200 m event focus; neuromuscular speed and race-pace specificity"
    case .distance:
        return "Distance - 400 m+ event focus; aerobic capacity and pacing strategy"
    case .mixed:
        return "Mixed - IM/versatile approach; balanced speed–endurance"
    case .none:
        return "Single-level tier (no sub-tiers)"
    case .a, .b, .c:
        return subTier.description(for: tier)
    }
}
