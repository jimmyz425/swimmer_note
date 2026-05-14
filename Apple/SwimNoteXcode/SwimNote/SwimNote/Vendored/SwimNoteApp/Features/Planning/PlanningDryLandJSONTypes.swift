import Foundation

/// JSON structure for unified dry land exercises (`dry-land-exercises.json`).
struct DryLandExerciseJSON: Codable {
    let id: String // Unique identifier for exercise matching
    let name: String
    let aliases: [String]? // Alternative names LLM might use
    let description: String
    let strokeFocusPoints: [String: String] // Stroke-specific focus points
    let category: String
    let defaultSetsReps: String
}

struct DryLandTrainingData: Codable {
    let version: String
    let exercises: [DryLandExerciseJSON]
}
