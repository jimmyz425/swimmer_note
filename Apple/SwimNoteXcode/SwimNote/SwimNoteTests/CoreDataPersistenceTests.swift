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

    @Test("clearAllData wipes every entity in the model (TimerSession included)")
    @MainActor
    func clearAllDataWipesEverything() async throws {
        let controller = try await makeIsolatedController()
        let context = controller.viewContext
        let now = SwimNoteDateFormatting.string(from: Date())
        let userId = "wipe-user"

        // Insert one row of each entity declared in SwimNote.xcdatamodel.
        let profile = UserProfile(
            id: userId,
            name: "Wipe Me",
            birthday: "2000-01-01",
            sex: .male,
            skillLevel: .intermediate,
            weeklySessionTarget: 3,
            preferredStrokes: [.freestyle],
            personalBests: PersonalBests(),
            trainingGoals: [],
            createdAt: now,
            updatedAt: now
        )
        _ = try controller.createUserProfileEntity(from: profile, in: context)

        let goal = Goal(
            id: UUID().uuidString,
            type: .technique,
            description: "Wipe goal",
            status: .planned,
            createdAt: now,
            updatedAt: now
        )
        let note = TrainingNote(
            userId: userId,
            date: "2026-05-04",
            strokeFocus: [.freestyle],
            techniqueFocus: [],
            goals: [goal],
            notes: "",
            createdAt: now,
            updatedAt: now
        )
        _ = try controller.createTrainingNoteEntity(from: note, in: context)
        _ = controller.createGoalEntity(from: goal, in: context)

        let segment = SessionSegment(distance: "200", description: "easy")
        let session = DetailedSession(
            id: UUID().uuidString,
            sessionNumber: 1,
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
            scheduledDate: nil,
            timeOfDay: nil,
            isCompleted: false,
            isAssigned: false
        )
        let plan = WeeklyTrainingPlan(
            overview: PlanOverview(weekFocus: "test"),
            schedule: [],
            detailedSessions: [session],
            dryLandProgram: nil,
            weeklyGoals: nil,
            techniqueProgressPlan: nil,
            notes: "",
            weekStartingDate: Self.localMidnight(yyyyMMdd: "2026-05-04"),
            poolTypeRaw: nil
        )
        let planEntity = try controller.createWeeklyPlanEntity(from: plan, userId: userId, in: context)
        let sessionEntity = controller.createDetailedSessionEntity(from: session, in: context)
        sessionEntity.weeklyPlan = planEntity

        let dryLand = DryLandExercisePlan(
            id: UUID().uuidString,
            exercise: "Push-ups",
            setsReps: "3x10",
            focus: nil,
            techniqueSupport: nil
        )
        let dryEntity = controller.createDryLandEntity(from: dryLand, in: context)
        dryEntity.weeklyPlan = planEntity

        let measurement = TechniqueMeasurement(
            id: UUID().uuidString,
            userId: userId,
            strokeId: .freestyle,
            strokeCount: 14,
            lapTime: 30.0,
            effortZone: 3
        )
        _ = controller.createTechniqueMeasurementEntity(from: measurement, in: context)

        let timerSession = TimerSession(
            userId: userId,
            strokeId: .freestyle,
            totalDistance: 200,
            splits: [TimerSplit(splitNumber: 1, cumulativeTime: 30, lapTime: 30)],
            totalTime: 30
        )
        _ = try controller.createTimerSessionEntity(from: timerSession, in: context)
        try context.save()

        let entityNames = [
            "UserProfile",
            "TrainingNote",
            "Goal",
            "WeeklyTrainingPlan",
            "DetailedSession",
            "DryLandExercisePlan",
            "TechniqueMeasurement",
            "TimerSession",
        ]
        for name in entityNames {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: name)
            let count = try context.count(for: request)
            #expect(count > 0, "Pre-clear \(name) should have rows")
        }

        // Use a throwaway app-support dir; clearAllData doesn't touch it but
        // CoreDataMigration's initializer eagerly builds JSON repos against it.
        let appSupport = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwimNoteWipe-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: appSupport) }
        let migration = CoreDataMigration(controller: controller, appSupportURL: appSupport)
        await migration.clearAllData()

        // The batch delete bypasses the in-memory context, so reset it before
        // counting to make sure we're reading the post-clear store state.
        context.reset()
        for name in entityNames {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: name)
            let count = try context.count(for: request)
            #expect(count == 0, "\(name) should be empty after clearAllData")
        }
    }

    @Test("CoreDataMigration copies active profile id and removes JSON sources")
    @MainActor
    func migrationMovesActiveProfileAndCleansJSON() async throws {
        let now = SwimNoteDateFormatting.string(from: Date())
        let profile = UserProfile(
            id: UUID().uuidString,
            name: "Migrated Swimmer",
            birthday: "2000-01-01",
            sex: .male,
            skillLevel: .intermediate,
            weeklySessionTarget: 3,
            preferredStrokes: [.freestyle],
            personalBests: PersonalBests(),
            trainingGoals: [],
            createdAt: now,
            updatedAt: now
        )

        // Build a per-test app-support sandbox with the JSON layout the
        // pre-migration app produced.
        let appSupport = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwimNoteMigration-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: appSupport) }

        let configDir = appSupport.appendingPathComponent("config", isDirectory: true)
        let notesDir = appSupport.appendingPathComponent("notes", isDirectory: true)
        let plansDir = appSupport.appendingPathComponent("weekly-plans", isDirectory: true)
        let jsonProfileRepo = JSONUserProfileRepository(configDirectory: configDir)
        try await jsonProfileRepo.save(profile)
        try await jsonProfileRepo.setActiveProfile(id: profile.id)

        // Drop a placeholder file in each per-profile directory so we can
        // assert the cleanup actually wipes them after migration.
        let profileNotesDir = notesDir.appendingPathComponent(profile.id, isDirectory: true)
        let profilePlansDir = plansDir.appendingPathComponent(profile.id, isDirectory: true)
        try FileManager.default.createDirectory(at: profileNotesDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: profilePlansDir, withIntermediateDirectories: true)
        try Data().write(to: profileNotesDir.appendingPathComponent("placeholder.json"))
        try Data().write(to: profilePlansDir.appendingPathComponent("placeholder.json"))

        let activeProfileFile = configDir.appendingPathComponent("active_profile.json")
        #expect(FileManager.default.fileExists(atPath: activeProfileFile.path))

        // Force the version-gated re-migration path so we exercise the full flow.
        let priorActiveId = UserDefaults.standard.string(forKey: "activeProfileId")
        let priorVersion = UserDefaults.standard.integer(forKey: "coreDataMigrationVersion")
        UserDefaults.standard.removeObject(forKey: "activeProfileId")
        UserDefaults.standard.set(0, forKey: "coreDataMigrationVersion")
        defer {
            if let priorActiveId {
                UserDefaults.standard.set(priorActiveId, forKey: "activeProfileId")
            } else {
                UserDefaults.standard.removeObject(forKey: "activeProfileId")
            }
            UserDefaults.standard.set(priorVersion, forKey: "coreDataMigrationVersion")
        }

        let controller = try await makeIsolatedController()
        let migration = CoreDataMigration(controller: controller, appSupportURL: appSupport)
        try await migration.migrateAll()

        #expect(UserDefaults.standard.string(forKey: "activeProfileId") == profile.id)
        #expect(!FileManager.default.fileExists(atPath: activeProfileFile.path))
        #expect(!FileManager.default.fileExists(atPath: profileNotesDir.path))
        #expect(!FileManager.default.fileExists(atPath: profilePlansDir.path))

        // The migrated profile should be queryable through the Core Data repo.
        let coreDataRepo = CoreDataUserProfileRepository(controller: controller)
        let migrated = await coreDataRepo.profile(id: profile.id)
        #expect(migrated?.name == "Migrated Swimmer")
    }
}

#endif
