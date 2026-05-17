import Foundation

extension CombinedToolExecutor {
    // MARK: - Dry Land Exercises Tool

    func getDryLandExercises(stroke: String?) throws -> String {
        guard let stroke else {
            throw ToolError.missingParameter("stroke")
        }

        let validStrokes = ["freestyle", "backstroke", "breaststroke", "butterfly"]
        guard validStrokes.contains(stroke.lowercased()) else {
            throw ToolError.invalidParameter("stroke", stroke)
        }

        let catalog = try DryLandExerciseCatalog.loadCatalog()
        let result = DryLandExerciseCatalog.exercises(for: stroke, catalog: catalog)

        return try encodeJSON([
            "stroke": stroke,
            "count": result.count,
            "exercises": result,
            "note": "Return ONLY the exercise ID (e.g. 'plank-hold'). The app will match IDs to full drill details.",
        ])
    }
}
