import Foundation

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
            "weekFocus": "string - must be 'Active Recovery'"
          },
          "schedule": [{
            "sessionNumber": 1,
            "poolSession": "string - session name",
            "focus": "string - focus description",
            "sessionType": "string - must be 'recovery'"
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
          "notes": "string - recovery rationale"
        }

        ALL string fields must be actual text, not booleans (except sessionNumber which is Int).
        Generate \(context.effectiveWeeklySessionCount) LIGHT sessions. No sprint work. Extended rest.
        OUTPUT ONLY JSON.
        """
    }

    public func guidanceFiles() -> [String] {
        return ["coach_prompt.md", "swimming-coach-role-reference.md", "usa-swimming-club-training-structure.md"]
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
