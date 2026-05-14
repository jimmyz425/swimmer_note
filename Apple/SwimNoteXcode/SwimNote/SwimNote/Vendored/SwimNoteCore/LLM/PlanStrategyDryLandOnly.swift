import Foundation

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
