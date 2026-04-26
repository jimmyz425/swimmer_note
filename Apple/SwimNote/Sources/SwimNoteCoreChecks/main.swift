import Foundation
import SwimNoteCore

enum CheckFailure: Error, CustomStringConvertible {
    case failed(String)

    var description: String {
        switch self {
        case .failed(let message):
            return message
        }
    }
}

func check(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw CheckFailure.failed(message)
    }
}

@main
struct SwimNoteCoreChecks {
    static func main() async throws {
        try checkLegacyTrainingNoteDecoding()
        try await checkNoteRepositoryPersistence()
        try await checkJSONRepositoryRejectsUnsafeDates()
        try checkLLMRejectsInsecureBaseURL()
        try checkContentLoader()
        try checkTechniqueGoalCreation()
        try checkCoachingPrompt()
        try checkVideoMetrics()
        print("SwimNoteCoreChecks passed")
    }

    static func checkLegacyTrainingNoteDecoding() throws {
        let data = Data("""
        {
          "date": "2026-04-23",
          "strokeFocus": ["freestyle"],
          "techniqueFocus": ["body_position"],
          "goals": [
            {
              "id": "goal_1",
              "type": "technique",
              "target": "body_position",
              "strokeId": "freestyle",
              "description": "Horizontal Body Position",
              "techniqueNodeId": "free_body",
              "revisit": true,
              "metrics": {},
              "coachingTips": "Keep hips high",
              "status": "pending",
              "createdAt": "2026-04-23T14:08:55.351Z",
              "updatedAt": "2026-04-23T15:51:23.359Z"
            }
          ],
          "notes": "Easy aerobic session",
          "createdAt": "2026-04-23T11:31:29.864Z",
          "updatedAt": "2026-04-23T15:51:23.359Z"
        }
        """.utf8)

        let note = try SwimNoteJSONDecoder().decode(TrainingNote.self, from: data)
        try check(note.date == "2026-04-23", "legacy note date should decode")
        try check(note.strokeFocus == [.freestyle], "stroke focus should decode")
        try check(note.techniqueFocus == [.bodyPosition], "technique focus should decode")
        try check(note.goals.first?.status == .planned, "legacy pending status should normalize to planned")
    }

    static func checkNoteRepositoryPersistence() async throws {
        let repository = InMemoryTrainingNoteRepository()
        try await repository.save(.empty(date: "2026-04-22"))
        try await repository.save(.empty(date: "2026-04-23"))

        let allNotes = await repository.listNotes()
        try check(allNotes.map(\.date) == ["2026-04-23", "2026-04-22"], "notes should sort newest first")
        let savedNote = await repository.note(for: "2026-04-22")
        try check(savedNote?.date == "2026-04-22", "saved note should be readable")
    }

    static func checkJSONRepositoryRejectsUnsafeDates() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwimNoteCoreChecks-\(UUID().uuidString)")
        let repository = JSONTrainingNoteRepository(notesDirectory: tempDirectory)
        let unsafeNote = TrainingNote.empty(date: "../escape")

        do {
            try await repository.save(unsafeNote)
            throw CheckFailure.failed("unsafe note date should be rejected")
        } catch SwimNotePersistenceError.invalidDate {
            return
        }
    }

    static func checkContentLoader() throws {
        let loader = BundleContentLoader.bundled()
        let strokes = try loader.loadStrokes()
        let techniques = try loader.loadTechniques()
        let freestyleTree = try loader.loadTechniqueTree(strokeId: .freestyle)

        try check(strokes.map(\.id).contains(.freestyle), "freestyle stroke should load")
        try check(techniques.map(\.id).contains(.bodyPosition), "body position technique should load")
        try check(freestyleTree.strokeId == .freestyle, "freestyle tree should load")
        try check(freestyleTree.nodes.contains { $0.id == "free_body_position" }, "freestyle tree should contain body position node")
    }

    static func checkLLMRejectsInsecureBaseURL() throws {
        do {
            _ = try LLMConfiguration(
                provider: .openAICompatible,
                apiKeyReference: "test",
                baseURL: URL(string: "http://example.com"),
                modelName: "test"
            )
            throw CheckFailure.failed("LLM configuration should reject plaintext base URLs")
        } catch LLMConfigurationError.insecureBaseURL {
            return
        }
    }

    static func checkTechniqueGoalCreation() throws {
        let node = TechniqueTreeNode(
            id: "free_body_position",
            techniqueId: "body_position",
            level: 1,
            name: "Body Position & Streamline",
            description: "Minimize drag.",
            revisit: true,
            metrics: nil,
            prerequisites: [],
            children: ["free_flutter_kick"],
            sourceFile: "freestyle-01-body-position"
        )

        let goal = Goal.fromTechniqueNode(node, strokeId: .freestyle, date: Date(timeIntervalSince1970: 0))
        try check(goal.type == .technique, "tree goal should be technique type")
        try check(goal.target == "body_position", "tree goal should target node technique")
        try check(goal.strokeId == .freestyle, "tree goal should preserve stroke")
        try check(goal.techniqueNodeId == "free_body_position", "tree goal should reference node")
    }

    static func checkCoachingPrompt() throws {
        let node = TechniqueTreeNode(
            id: "free_body_position",
            techniqueId: "body_position",
            level: 1,
            name: "Body Position & Streamline",
            description: "Minimize drag.",
            revisit: true,
            metrics: nil,
            prerequisites: [],
            children: [],
            sourceFile: nil
        )

        let request = CoachingPromptBuilder().request(for: node)
        try check(request.systemRole == "expert_swimming_coach", "coaching system role should be stable")
        try check(request.prompt.contains("Give 3-4 bullet-point tips"), "coaching prompt should request concise bullets")
        try check(request.prompt.contains("max 10 words"), "coaching prompt should preserve word constraint")
        try check(request.prompt.contains("Body Position & Streamline"), "coaching prompt should include node name")
    }

    static func checkVideoMetrics() throws {
        var landmarks = Array(repeating: PoseLandmark(x: 0.5, y: 0.5, z: 0, visibility: 1), count: PoseLandmarkIndex.count)
        landmarks[PoseLandmarkIndex.leftShoulder.rawValue] = PoseLandmark(x: 0.2, y: 0.4, z: 0, visibility: 1)
        landmarks[PoseLandmarkIndex.rightShoulder.rawValue] = PoseLandmark(x: 0.4, y: 0.4, z: 0, visibility: 1)
        landmarks[PoseLandmarkIndex.leftHip.rawValue] = PoseLandmark(x: 0.2, y: 0.6, z: 0, visibility: 1)
        landmarks[PoseLandmarkIndex.rightHip.rawValue] = PoseLandmark(x: 0.4, y: 0.6, z: 0, visibility: 1)
        landmarks[PoseLandmarkIndex.leftElbow.rawValue] = PoseLandmark(x: 0.2, y: 0.35, z: 0, visibility: 1)
        landmarks[PoseLandmarkIndex.leftWrist.rawValue] = PoseLandmark(x: 0.2, y: 0.50, z: 0, visibility: 1)

        let metrics = PoseMetricsAnalyzer().analyze(frames: [PoseFrame(timestamp: 0, landmarks: landmarks)])
        try check(metrics.bodyAngleAverage.isFinite, "body angle should be finite")
        try check(metrics.elbowHeightAverage > 0, "elbow height should detect high elbow")
    }
}
