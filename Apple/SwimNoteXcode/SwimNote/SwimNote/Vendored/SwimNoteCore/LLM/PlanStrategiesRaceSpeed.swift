import Foundation

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
        Generate \(context.effectiveWeeklySessionCount) RACE PREP sessions. Goal pace work. Start/turn practice.
        OUTPUT ONLY JSON.
        """
    }

    public func guidanceFiles() -> [String] {
        return ["coach_prompt.md", "swimming-coach-role-reference.md"]
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
        Generate \(context.effectiveWeeklySessionCount) SPEED sessions. Sprint intervals. High rest ratios.
        OUTPUT ONLY JSON.
        """
    }

    public func guidanceFiles() -> [String] {
        return ["coach_prompt.md", "swimming-coach-role-reference.md"]
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
