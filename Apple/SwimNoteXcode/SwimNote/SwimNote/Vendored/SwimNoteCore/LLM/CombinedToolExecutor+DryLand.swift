import Foundation

extension CombinedToolExecutor {
    // MARK: - Dry Land Exercises Tool

    func getDryLandExercises(stroke: String?) throws -> String {
        guard let stroke else {
            throw ToolError.missingParameter("stroke")
        }

        // Validate stroke
        let validStrokes = ["freestyle", "backstroke", "breaststroke", "butterfly"]
        guard validStrokes.contains(stroke.lowercased()) else {
            throw ToolError.invalidParameter("stroke", stroke)
        }

        // Load the unified dry land JSON file
        let filename = "dry-land-exercises.json"

        // Try to find the file in bundle
        guard let url = Bundle.main.url(forResource: "dry-land-exercises", withExtension: "json", subdirectory: "swimming-strokes") ??
                        Bundle.main.url(forResource: "dry-land-exercises", withExtension: "json", subdirectory: "Resources/swimming-strokes") ??
                        Bundle.main.url(forResource: "dry-land-exercises", withExtension: "json") else {
            throw ToolError.executionError("Could not find \(filename)")
        }

        guard let data = try? Data(contentsOf: url) else {
            throw ToolError.executionError("Could not read \(filename)")
        }

        // Parse JSON
        struct DryLandExercise: Codable {
            let id: String
            let name: String
            let category: String
            let defaultSetsReps: String
            let strokeFocusPoints: [String: String]?
        }

        struct DryLandData: Codable {
            let version: String
            let exercises: [DryLandExercise]
        }

        guard let dryLandData = try? JSONDecoder().decode(DryLandData.self, from: data) else {
            throw ToolError.executionError("Could not parse \(filename)")
        }

        // Filter exercises that have focus points for this stroke
        let exercisesForStroke = dryLandData.exercises.filter { exercise in
            exercise.strokeFocusPoints?[stroke.lowercased()] != nil
        }

        // Return with id and stroke-specific focus for LLM to choose
        let result: [[String: String]] = exercisesForStroke.map { exercise in
            [
                "id": exercise.id,
                "name": exercise.name,
                "category": exercise.category,
                "defaultSetsReps": exercise.defaultSetsReps,
                "focus": exercise.strokeFocusPoints?[stroke.lowercased()] ?? ""
            ]
        }

        return try encodeJSON([
            "stroke": stroke,
            "count": result.count,
            "exercises": result,
            "note": "Return ONLY the exercise ID (e.g. 'plank-hold'). The app will match IDs to full drill details."
        ])
    }
}
