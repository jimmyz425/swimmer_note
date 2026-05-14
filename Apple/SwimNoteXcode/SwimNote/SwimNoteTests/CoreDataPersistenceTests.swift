//
//  CoreDataPersistenceTests.swift
//  SwimNoteTests
//
//  Tests for Core Data <-> domain round-trip behaviour.
//

import Testing
import Foundation
@testable import SwimNote

#if canImport(CoreData)
import CoreData

// MARK: - Test helpers

@MainActor
private func makeIsolatedController(file: StaticString = #file, line: UInt = #line) async throws -> CoreDataPersistenceController {
    // One sqlite per test, deleted on success at the end.
    let storeURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("SwimNoteTest-\(UUID().uuidString).sqlite")
    let controller = CoreDataPersistenceController(storageURL: storeURL)
    try await controller.load()
    return controller
}

private func makeSession(
    sessionNumber: Int,
    scheduledDate: Date?,
    timeOfDay: SessionTimeOfDay?
) -> DetailedSession {
    let segment = SessionSegment(distance: "200", description: "easy")
    return DetailedSession(
        id: UUID().uuidString,
        sessionNumber: sessionNumber,
        focus: "test",
        warmUp: segment,
        drillSet: segment,
        mainSet: segment,
        secondarySet: nil,
        coolDown: segment,
        techniqueFocus: "balance",
        techniqueFileRef: nil,
        addressesGoal: nil,
        sessionType: nil,
        progressionRationale: nil,
        sessionNotes: nil,
        scheduledDate: scheduledDate,
        timeOfDay: timeOfDay,
        isCompleted: false,
        isAssigned: scheduledDate != nil
    )
}

private func makePlan(
    weekStarting: Date,
    sessions: [DetailedSession]
) -> WeeklyTrainingPlan {
    WeeklyTrainingPlan(
        overview: PlanOverview(weekFocus: "test"),
        schedule: [],
        detailedSessions: sessions,
        dryLandProgram: nil,
        weeklyGoals: nil,
        techniqueProgressPlan: nil,
        notes: "",
        weekStartingDate: weekStarting,
        poolTypeRaw: nil
    )
}

// MARK: - Tests

@Suite("Core Data persistence", .serialized)
struct CoreDataPersistenceTests {

    /// `DateFormatter("yyyy-MM-dd").date(from:)` interprets the string in the local
    /// timezone, which is what `CoreDataWeeklyPlanRepository.plan(for:weekStarting:)`
    /// and `sessionsForDate(for:date:)` use internally. Mirror that here so the
    /// `Date` we save and the `Date` they look up are the same value.
    private static func localMidnight(yyyyMMdd: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: yyyyMMdd)!
    }

    @Test("DetailedSession.timeOfDay survives a save+load round-trip")
    @MainActor
    func timeOfDayRoundTrip() async throws {
        let controller = try await makeIsolatedController()
        let repo = CoreDataWeeklyPlanRepository(controller: controller)

        let weekStart = Self.localMidnight(yyyyMMdd: "2026-05-04")

        let morning = makeSession(sessionNumber: 1, scheduledDate: weekStart, timeOfDay: .morning)
        let afternoon = makeSession(sessionNumber: 2, scheduledDate: weekStart, timeOfDay: .afternoon)
        let plan = makePlan(weekStarting: weekStart, sessions: [morning, afternoon])

        try await repo.save(plan, for: "user-1")

        let loaded = await repo.plan(for: "user-1", weekStarting: "2026-05-04")
        try #require(loaded != nil)
        let loadedSessions = loaded!.detailedSessions.sorted { $0.sessionNumber < $1.sessionNumber }
        #expect(loadedSessions.count == 2)
        #expect(loadedSessions[0].timeOfDay == .morning)
        #expect(loadedSessions[1].timeOfDay == .afternoon)
    }

    @Test("sessionsForDate sorts morning before afternoon by stored timeOfDay")
    @MainActor
    func sessionsForDateSortedByTimeOfDay() async throws {
        let controller = try await makeIsolatedController()
        let repo = CoreDataWeeklyPlanRepository(controller: controller)

        let day = Self.localMidnight(yyyyMMdd: "2026-05-04")

        // Insert in reverse order to prove sorting matters.
        let afternoon = makeSession(sessionNumber: 2, scheduledDate: day, timeOfDay: .afternoon)
        let morning = makeSession(sessionNumber: 1, scheduledDate: day, timeOfDay: .morning)
        let plan = makePlan(weekStarting: day, sessions: [afternoon, morning])
        try await repo.save(plan, for: "user-2")

        let sessions = await repo.sessionsForDate(for: "user-2", date: "2026-05-04")
        #expect(sessions.count == 2)
        #expect(sessions.first?.timeOfDay == .morning)
        #expect(sessions.last?.timeOfDay == .afternoon)
    }
}

#endif
