//
//  CombinedToolExecutorTests.swift
//  SwimNoteTests
//
//  Tests for combined tool executor including user data tools
//

import Testing
import Foundation
@testable import SwimNote

struct CombinedToolExecutorTests {

    // MARK: - Test Data Helpers

    func createTestProfile() -> UserProfile {
        let now = SwimNoteDateFormatting.string(from: Date())
        return UserProfile(
            id: UUID().uuidString,
            name: "Test Swimmer",
            birthday: "2000-01-01",
            sex: .male,
            skillLevel: .intermediate,
            weeklySessionTarget: 3,
            preferredStrokes: [.freestyle, .backstroke],
            personalBests: PersonalBests(
                freestyle50m: 28.5,
                backstroke50m: 32.0
            ),
            trainingGoals: ["Improve technique"],
            createdAt: now,
            updatedAt: now
        )
    }

    func createTestNote(date: String, strokes: [StrokeID] = [], goals: [Goal] = [], notes: String = "") -> TrainingNote {
        let now = SwimNoteDateFormatting.string(from: Date())
        return TrainingNote(
            userId: "test-user",
            date: date,
            strokeFocus: strokes,
            techniqueFocus: [],
            goals: goals,
            notes: notes,
            createdAt: now,
            updatedAt: now
        )
    }

    func createTestGoal(description: String, status: GoalStatus, stroke: StrokeID? = nil) -> Goal {
        let now = SwimNoteDateFormatting.string(from: Date())
        return Goal(
            id: UUID().uuidString,
            type: .technique,
            strokeId: stroke,
            description: description,
            status: status,
            goalKind: .keyPoint,
            createdAt: now,
            updatedAt: now
        )
    }

    // MARK: - User Data Tools Tests

    @Test("get_user_profile returns error when no profile")
    func getUserProfileNoProfile() async throws {
        let executor = await CombinedToolExecutor(
            contentLoader: BundleContentLoader(bundle: Bundle.main),
            profile: nil,
            notes: []
        )

        let toolCall = ToolCall(
            id: "call_1",
            function: ToolCallFunction(name: "get_user_profile", arguments: "{}")
        )

        let result = try await executor.execute(toolCall)
        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["error"] as? String == "No active profile")
    }

    @Test("get_user_profile returns profile data")
    func getUserProfileWithProfile() async throws {
        let profile = createTestProfile()
        let executor = await CombinedToolExecutor(
            contentLoader: BundleContentLoader(bundle: Bundle.main),
            profile: profile,
            notes: []
        )

        let toolCall = ToolCall(
            id: "call_1",
            function: ToolCallFunction(name: "get_user_profile", arguments: "{}")
        )

        let result = try await executor.execute(toolCall)
        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["name"] as? String == "Test Swimmer")
        #expect(json?["level"] as? String == "intermediate")
        #expect(json?["weekly_target"] as? Int == 3)
        #expect((json?["strokes"] as? [String])?.contains("freestyle") == true)
    }

    @Test("get_training_history returns empty when no notes")
    func getTrainingHistoryNoNotes() async throws {
        let executor = await CombinedToolExecutor(
            contentLoader: BundleContentLoader(bundle: Bundle.main),
            profile: nil,
            notes: []
        )

        let toolCall = ToolCall(
            id: "call_1",
            function: ToolCallFunction(name: "get_training_history", arguments: "{}")
        )

        let result = try await executor.execute(toolCall)
        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["days_returned"] as? Int == 0)
        #expect((json?["sessions"] as? [String])?.isEmpty == true)
    }

    @Test("get_training_history returns recent sessions")
    func getTrainingHistoryWithNotes() async throws {
        let notes = [
            createTestNote(date: "2026-04-28", strokes: [.freestyle], notes: "Good session"),
            createTestNote(date: "2026-04-27", strokes: [.backstroke], notes: "Focus on rotation"),
            createTestNote(date: "2026-04-26", strokes: [.freestyle, .backstroke], notes: "Mixed practice")
        ]
        let executor = await CombinedToolExecutor(
            contentLoader: BundleContentLoader(bundle: Bundle.main),
            profile: nil,
            notes: notes
        )

        let toolCall = ToolCall(
            id: "call_1",
            function: ToolCallFunction(name: "get_training_history", arguments: "{\"days\": 7}")
        )

        let result = try await executor.execute(toolCall)
        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["days_returned"] as? Int == 3)
        let sessions = json?["sessions"] as? [String]
        #expect(sessions?.count == 3)
        #expect(sessions?.first?.contains("2026-04-28") == true)
    }

    @Test("get_training_history respects days limit")
    func getTrainingHistoryDaysLimit() async throws {
        let notes = (0..<20).map { i in
            createTestNote(date: "2026-04-\(String(format: "%02d", 28 - i))", strokes: [.freestyle], notes: "Day \(i)")
        }
        let executor = await CombinedToolExecutor(
            contentLoader: BundleContentLoader(bundle: Bundle.main),
            profile: nil,
            notes: notes
        )

        let toolCall = ToolCall(
            id: "call_1",
            function: ToolCallFunction(name: "get_training_history", arguments: "{\"days\": 5}")
        )

        let result = try await executor.execute(toolCall)
        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["days_returned"] as? Int == 5)
    }

    @Test("get_training_history limits to 14 days maximum")
    func getTrainingHistoryMaxLimit() async throws {
        let notes = (0..<30).map { i in
            createTestNote(date: "2026-04-\(String(format: "%02d", max(1, 28 - i)))", strokes: [.freestyle], notes: "")
        }
        let executor = await CombinedToolExecutor(
            contentLoader: BundleContentLoader(bundle: Bundle.main),
            profile: nil,
            notes: notes
        )

        let toolCall = ToolCall(
            id: "call_1",
            function: ToolCallFunction(name: "get_training_history", arguments: "{\"days\": 30}")
        )

        let result = try await executor.execute(toolCall)
        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["days_returned"] as? Int == 14)
    }

    @Test("get_active_goals returns empty when no goals")
    func getActiveGoalsNoGoals() async throws {
        let executor = await CombinedToolExecutor(
            contentLoader: BundleContentLoader(bundle: Bundle.main),
            profile: nil,
            notes: []
        )

        let toolCall = ToolCall(
            id: "call_1",
            function: ToolCallFunction(name: "get_active_goals", arguments: "{}")
        )

        let result = try await executor.execute(toolCall)
        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["count"] as? Int == 0)
        #expect((json?["goals"] as? [[String: Any]])?.isEmpty == true)
    }

    @Test("get_active_goals returns only active goals")
    func getActiveGoalsOnlyActive() async throws {
        let activeGoal = createTestGoal(description: "Active goal", status: .planned, stroke: .freestyle)
        let achievedGoal = createTestGoal(description: "Achieved goal", status: .achieved, stroke: .backstroke)
        let notes = [
            createTestNote(date: "2026-04-28", strokes: [], goals: [activeGoal, achievedGoal], notes: "")
        ]
        let executor = await CombinedToolExecutor(
            contentLoader: BundleContentLoader(bundle: Bundle.main),
            profile: nil,
            notes: notes
        )

        let toolCall = ToolCall(
            id: "call_1",
            function: ToolCallFunction(name: "get_active_goals", arguments: "{}")
        )

        let result = try await executor.execute(toolCall)
        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["count"] as? Int == 1)
        let goals = json?["goals"] as? [[String: Any]]
        #expect(goals?.first?["description"] as? String == "Active goal")
    }

    @Test("get_active_goals limits to 5 goals")
    func getActiveGoalsLimit() async throws {
        // Create 10 goals with unique IDs across multiple notes
        var allGoals: [Goal] = []
        for i in 0..<10 {
            allGoals.append(createTestGoal(description: "Goal \(i)", status: .planned, stroke: .freestyle))
        }

        // Split goals across 2 notes to test cross-note aggregation
        let notes = [
            createTestNote(date: "2026-04-28", strokes: [], goals: Array(allGoals[0..<5]), notes: ""),
            createTestNote(date: "2026-04-27", strokes: [], goals: Array(allGoals[5..<10]), notes: "")
        ]
        let executor = await CombinedToolExecutor(
            contentLoader: BundleContentLoader(bundle: Bundle.main),
            profile: nil,
            notes: notes
        )

        let toolCall = ToolCall(
            id: "call_1",
            function: ToolCallFunction(name: "get_active_goals", arguments: "{}")
        )

        let result = try await executor.execute(toolCall)
        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Should get exactly 5 goals (limit)
        #expect((json?["count"] as? Int) == 5)
    }

    @Test("get_training_calendar returns calendar data")
    func getTrainingCalendar() async throws {
        // Use dates relative to today
        let today = Date()
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!

        let notes = [
            createTestNote(date: SwimNoteDateFormatting.shortDateString(from: yesterday), strokes: [.freestyle], notes: ""),
            createTestNote(date: SwimNoteDateFormatting.shortDateString(from: twoDaysAgo), strokes: [.backstroke], notes: "")
        ]
        let executor = await CombinedToolExecutor(
            contentLoader: BundleContentLoader(bundle: Bundle.main),
            profile: nil,
            notes: notes
        )

        let toolCall = ToolCall(
            id: "call_1",
            function: ToolCallFunction(name: "get_training_calendar", arguments: "{\"weeks\": 1}")
        )

        let result = try await executor.execute(toolCall)
        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["weeks_shown"] as? Int == 1)
        let calendarData = json?["calendar"] as? [[String: Any]]
        #expect(calendarData != nil)
        #expect(calendarData?.isEmpty == false)

        // Check that sessions are marked correctly
        let sessionDays = calendarData?.filter { ($0["had_session"] as? Bool) == true }
        #expect(sessionDays?.count == 2)
    }

    @Test("get_training_calendar includes statistics")
    func getTrainingCalendarStatistics() async throws {
        // Use dates relative to today
        let today = Date()
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: today)!

        let profile = createTestProfile()
        let notes = [
            createTestNote(date: SwimNoteDateFormatting.shortDateString(from: yesterday), strokes: [.freestyle], notes: ""),
            createTestNote(date: SwimNoteDateFormatting.shortDateString(from: twoDaysAgo), strokes: [.freestyle], notes: ""),
            createTestNote(date: SwimNoteDateFormatting.shortDateString(from: threeDaysAgo), strokes: [.freestyle], notes: "")
        ]
        let executor = await CombinedToolExecutor(
            contentLoader: BundleContentLoader(bundle: Bundle.main),
            profile: profile,
            notes: notes
        )

        let toolCall = ToolCall(
            id: "call_1",
            function: ToolCallFunction(name: "get_training_calendar", arguments: "{\"weeks\": 1}")
        )

        let result = try await executor.execute(toolCall)
        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        let statistics = json?["statistics"] as? [String: Any]
        #expect(statistics?["total_sessions"] as? Int == 3)
        #expect(statistics?["weekly_target"] as? Int == 3)
        #expect(statistics?["average_sessions_per_week"] != nil)
    }

    // MARK: - Error Handling Tests

    @Test("Combined executor throws unknownTool for invalid tool")
    func combinedUnknownTool() async throws {
        let executor = await CombinedToolExecutor(
            contentLoader: BundleContentLoader(bundle: Bundle.main),
            profile: nil,
            notes: []
        )

        let toolCall = ToolCall(
            id: "call_1",
            function: ToolCallFunction(name: "nonexistent_tool", arguments: "{}")
        )

        await #expect(throws: ToolError.unknownTool("nonexistent_tool")) {
            try await executor.execute(toolCall)
        }
    }
}
