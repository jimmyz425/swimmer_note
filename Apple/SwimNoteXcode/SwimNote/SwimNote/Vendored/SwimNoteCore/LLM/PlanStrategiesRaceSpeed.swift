import Foundation

// MARK: - Race Prep Strategy

public struct RacePrepStrategy: PlanGenerationStrategy, Sendable {
    public var planType: PlanType { .racePrep }

    public func buildSystemRole() -> String {
        return "expert_swimming_coach"
    }

    public func buildUserPrompt(context: PlanContext) -> String {
        let phaseRules: String
        if let phase = context.racePrepPhase {
            phaseRules = racePrepPhaseRules(phase)
        } else {
            phaseRules = """
        RACE PREP WEEK RULES (default — no phase specified):
        - Race-specific sets (goal pace work)
        - Start/turn practice in each session
        - Race simulation in at least one session
        - Mental preparation exercises
        """
        }

        return buildBasePrompt(context) + """

        \(phaseRules)

        JSON OUTPUT (exact types required):
        {
          "overview": {
            "weekFocus": "string - must reference race preparation phase"
          },
          "schedule": [{
            "sessionNumber": 1,
            "poolSession": "string - session name",
            "focus": "string - focus description",
            "sessionType": "string - must be 'race prep'"
          }],
          "detailedSessions": [{
            "sessionNumber": 1,
            "focus": "string - session focus",
            "techniqueFocus": "string - technique emphasis",
            "techniqueFileRef": "string - technique file reference",
            "warmUp": {"distance": "string"},
            "drillSet": {"distance": "string"},
            "mainSet": {"distance": "string", "description": "string"},
            "coolDown": {"distance": "string"},
            "progressionRationale": "string"
          }],
          "notes": "string - race prep rationale"
        }

        ALL string fields must be actual text, not booleans (except sessionNumber which is Int).
        Generate \(context.effectiveWeeklySessionCount) race prep sessions.
        OUTPUT ONLY JSON.
        """
    }

    public func guidanceFiles() -> [String] {
        return ["coach_prompt.md", "swimming-coach-role-reference.md", "usa-swimming-club-training-structure.md"]
    }

    public func coachingRules() -> String {
        return """
        RACE PREP:
        - Follow the phase-specific zone distribution from the embedded guidance
        - Start/turn practice in sessions appropriate to the phase
        - Race simulation increases as phases progress toward competition
        """
    }

    private func racePrepPhaseRules(_ phase: RacePrepPhase) -> String {
        switch phase {
        case .baseBuilding:
            return """
        RACE PREP — BASE BUILDING PHASE (typically 4–8 weeks):
        - Zone distribution: Zone 1-2 (55-65%), Zone 3 (10-15%), Zone 4 (5-10%), Zone 5-6 (0-8%)
        - Long repetitions (200-500m) for aerobic development
        - Low metabolic stress, technique consistency under moderate fatigue
        - Highest volume of all race prep phases
        - Start/turn practice: light, technique-focused
        - Session types: aerobic base / tempo introduction / technique maintenance
        """
        case .buildPhase:
            return """
        RACE PREP — BUILD PHASE (typically 4–8 weeks):
        - Zone distribution: Zone 1-2 (40-50%), Zone 3 (15-20%), Zone 4 (15-25%), Zone 5 (5-10%), Zone 6 (5-10%)
        - Moderate repetitions (100-300m) at threshold pace
        - Threshold work is the centerpiece
        - Introduce race-pace pieces in later sets
        - Start/turn practice: integrated into main sets
        - Session types: threshold main set / tempo bridge / race-pace introduction
        """
        case .sharpening:
            return """
        RACE PREP — SHARPENING PHASE (typically 3–6 weeks):
        - Zone distribution: Zone 1-2 (25-35%), Zone 3 (10-15%), Zone 4 (15-20%), Zone 5 (15-20%), Zone 6 (10-15%)
        - Short to moderate repetitions (25-200m)
        - Race-pace specificity increases dramatically
        - Volume decreases, quality over quantity
        - Race rehearsal sessions
        - Start/turn practice: race-pace precision
        - Session types: race-pace rehearsal / VO2max sets / sharpening sprints
        """
        case .competition:
            return """
        RACE PREP — COMPETITION PHASE (typically 2–6 weeks):
        - Zone distribution: Zone 1-2 (25-35%), Zone 3 (5-10%), Zone 4 (10-15%), Zone 5 (15-20%), Zone 6 (20-30%)
        - Very short repetitions (10-100m)
        - Full recovery between reps
        - Race-pace precision is paramount
        - Low total volume, very high quality
        - Session types: race rehearsal / meet simulation / speed maintenance
        """
        case .taper:
            return """
        RACE PREP — TAPER PHASE (typically 1–3 weeks):
        - Volume reduction: 41-60% from pre-taper volume
        - Intensity MAINTAINED: race-pace and faster work maintained or slightly increased
        - Frequency maintained: do not skip sessions (preserve neuromuscular patterns)
        - Zone distribution shifts from Week 1 (20-25% Zone 6) to final week (30-40% Zone 6)
        - Very short, sharp repetitions with full recovery
        - Session types: race-pace touch-ups / activation sprints / recovery focus
        """
        }
    }

    private func buildBasePrompt(_ context: PlanContext) -> String {
        return MixedTrainingStrategy().buildUserPrompt(context: context)
            .replacingOccurrences(of: "Generate a weekly training plan.", with: "Generate a RACE PREPARATION training plan.")
    }
}
