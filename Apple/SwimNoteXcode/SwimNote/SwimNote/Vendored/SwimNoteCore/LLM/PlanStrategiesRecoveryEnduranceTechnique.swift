import Foundation

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
        Generate \(context.effectiveWeeklySessionCount) LIGHT sessions. No sprint work. Extended rest.
        OUTPUT ONLY JSON.
        """
    }

    public func guidanceFiles() -> [String] {
        return ["coach_prompt.md", "swimming-coach-role-reference.md"]
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
        Generate \(context.effectiveWeeklySessionCount) ENDURANCE sessions. Long main sets. Pace targets.
        OUTPUT ONLY JSON.
        """
    }

    public func guidanceFiles() -> [String] {
        return ["coach_prompt.md", "swimming-coach-role-reference.md"]
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
        Generate \(context.effectiveWeeklySessionCount) TECHNIQUE sessions. 40% drills. Multiple technique refs.
        OUTPUT ONLY JSON.
        """
    }

    public func guidanceFiles() -> [String] {
        return ["coach_prompt.md", "swimming-coach-role-reference.md"]
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
