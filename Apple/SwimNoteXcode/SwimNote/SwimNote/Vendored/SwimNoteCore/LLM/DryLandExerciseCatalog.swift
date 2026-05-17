import Foundation

// MARK: - Dry land catalog (embedded in Phase 3 — no tool calls)

internal enum DryLandExerciseCatalog {

    struct ExerciseSummary: Codable {
        let id: String
        let name: String
        let category: String
        let defaultSetsReps: String
        let strokeFocusPoints: [String: String]?
    }

    struct Catalog: Codable {
        let version: String
        let exercises: [ExerciseSummary]
    }

    static func strokesFromWeeklyOutline(_ outline: WeeklyPlanOutline) -> [String] {
        let detected = outline.schedule.compactMap { session -> String? in
            if session.poolSession.contains("Freestyle") { return "freestyle" }
            if session.poolSession.contains("Backstroke") { return "backstroke" }
            if session.poolSession.contains("Breaststroke") { return "breaststroke" }
            if session.poolSession.contains("Butterfly") { return "butterfly" }
            return nil
        }
        let unique = Array(Set(detected))
        return unique.isEmpty ? ["freestyle"] : unique.sorted()
    }

    static func loadCatalog() throws -> Catalog {
        let url =
            Bundle.main.url(forResource: "dry-land-exercises", withExtension: "json", subdirectory: "swimming-strokes")
            ?? Bundle.main.url(forResource: "dry-land-exercises", withExtension: "json", subdirectory: "Resources/swimming-strokes")
            ?? Bundle.main.url(forResource: "dry-land-exercises", withExtension: "json")
        guard let url else {
            throw ToolError.executionError("Could not find dry-land-exercises.json")
        }
        let data = try Data(contentsOf: url)
        guard let catalog = try? JSONDecoder().decode(Catalog.self, from: data) else {
            throw ToolError.executionError("Could not parse dry-land-exercises.json")
        }
        return catalog
    }

    static func exercises(for stroke: String, catalog: Catalog) -> [[String: String]] {
        let key = stroke.lowercased()
        return catalog.exercises.compactMap { exercise in
            guard let focus = exercise.strokeFocusPoints?[key] else { return nil }
            return [
                "id": exercise.id,
                "name": exercise.name,
                "category": exercise.category,
                "defaultSetsReps": exercise.defaultSetsReps,
                "focus": focus,
            ]
        }
    }

    /// Prompt section listing allowed exercise IDs per stroke (Phase 3).
    static func allowedExercisesPromptSection(strokes: [String]) -> String {
        guard let catalog = try? loadCatalog() else {
            return "ALLOWED EXERCISES: Catalog unavailable — return empty dryLandExercises array."
        }
        var sections: [String] = [
            "ALLOWED DRY LAND EXERCISES (use ONLY these exerciseId values — do not invent IDs):",
        ]
        for stroke in strokes {
            let items = exercises(for: stroke, catalog: catalog)
            guard let data = try? JSONSerialization.data(withJSONObject: ["stroke": stroke, "exercises": items], options: [.prettyPrinted]),
                  let json = String(data: data, encoding: .utf8) else {
                continue
            }
            sections.append(json)
        }
        return sections.joined(separator: "\n\n")
    }
}
