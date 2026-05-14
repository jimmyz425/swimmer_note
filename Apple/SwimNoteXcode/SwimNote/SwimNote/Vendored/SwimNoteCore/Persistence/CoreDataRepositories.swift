@preconcurrency import Foundation
import OSLog
#if canImport(CoreData)
import CoreData
#endif

private let coreDataLog = Logger(subsystem: "com.swimnote.persistence", category: "CoreData")

extension Notification.Name {
    /// Posted (release builds only) when Core Data lightweight migration fails
    /// and the destructive fallback is about to delete the local store. The App
    /// can observe this to surface a banner so the user knows their device data
    /// was reset. P0-1G: in DEBUG we `fatalError` instead so the bug surfaces
    /// during development.
    public static let swimNoteCoreDataMigrationFailed = Notification.Name("com.swimnote.persistence.coreDataMigrationFailed")
}

// MARK: - Core Data Persistence Controller

#if canImport(CoreData)
@MainActor
public final class CoreDataPersistenceController: Sendable {
    public let container: NSPersistentContainer
    public let encoder = SwimNoteJSONEncoder()
    public let decoder = SwimNoteJSONDecoder()

    public init(modelName: String = "SwimNote", storageURL: URL? = nil) {
        // Load model from bundle - requires SwimNote.xcdatamodeld in Xcode project
        guard let modelURL = Bundle.main.url(forResource: modelName, withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: modelURL) else {
            // Create minimal empty model as fallback (will fail on actual operations)
            let emptyModel = NSManagedObjectModel()
            container = NSPersistentContainer(name: modelName, managedObjectModel: emptyModel)
            print("Warning: Core Data model not found. Using empty model.")
            return
        }

        container = NSPersistentContainer(name: modelName, managedObjectModel: model)

        if let storeURL = storageURL {
            let description = NSPersistentStoreDescription(url: storeURL)
            // Enable lightweight migration for schema changes
            description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
            description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
            container.persistentStoreDescriptions = [description]
        } else {
            // Enable lightweight migration for default store as well
            if let description = container.persistentStoreDescriptions.first {
                description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
                description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
            }
        }
    }

    public func load() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            container.loadPersistentStores { _, error in
                if let error {
                    let nsError = error as NSError
                    if nsError.code == 134140 || nsError.code == NSMigrationError || nsError.code == NSMigrationMissingSourceModelError {
                        // P0-1G: lightweight migration just failed. Pre-fix this
                        // silently deleted the user's local store via `print` +
                        // best-effort removeItem. That hides real model bugs in
                        // dev (you only notice the data loss) and would silently
                        // wipe customer data in release.
                        //
                        // DEBUG: crash hard so the developer sees it on the
                        // first launch after a bad model edit.
                        // Release: log at fault level via os.Logger, post a
                        // notification the App can observe to surface a banner,
                        // then proceed with the destructive recreate so the app
                        // still becomes usable instead of bricking.
                        coreDataLog.fault("Core Data migration failed: \(error.localizedDescription, privacy: .public) (code \(nsError.code))")

                        #if DEBUG
                        fatalError("Core Data migration failed: \(error). Bump the model version or fix the schema rather than relying on the destructive fallback.")
                        #else
                        NotificationCenter.default.post(
                            name: .swimNoteCoreDataMigrationFailed,
                            object: nil,
                            userInfo: ["error": error]
                        )

                        if let storeDescription = self.container.persistentStoreDescriptions.first,
                           let storeURL = storeDescription.url {
                            try? FileManager.default.removeItem(at: storeURL)
                            let shmURL = storeURL.deletingLastPathComponent().appendingPathComponent(storeURL.lastPathComponent + "-shm")
                            let walURL = storeURL.deletingLastPathComponent().appendingPathComponent(storeURL.lastPathComponent + "-wal")
                            try? FileManager.default.removeItem(at: shmURL)
                            try? FileManager.default.removeItem(at: walURL)
                        }
                        self.container.loadPersistentStores { _, retryError in
                            if let retryError {
                                continuation.resume(throwing: retryError)
                            } else {
                                self.container.viewContext.automaticallyMergesChangesFromParent = true
                                self.container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
                                continuation.resume()
                            }
                        }
                        #endif
                    } else {
                        continuation.resume(throwing: error)
                    }
                } else {
                    self.container.viewContext.automaticallyMergesChangesFromParent = true
                    self.container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
                    continuation.resume()
                }
            }
        }
    }

    public var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    public func newBackgroundContext() -> NSManagedObjectContext {
        container.newBackgroundContext()
    }

    // MARK: - Entity Creation Helpers

    public func createUserProfileEntity(from profile: UserProfile, in context: NSManagedObjectContext) throws -> UserProfileEntity {
        let entity = UserProfileEntity(context: context)
        entity.id = profile.id
        entity.name = profile.name
        entity.birthday = profile.birthday
        entity.sexRaw = profile.sex.rawValue
        entity.skillLevelRaw = profile.skillLevel.rawValue
        entity.weeklySessionTarget = Int32(profile.weeklySessionTarget)
        entity.preferredStrokesRaw = try encoder.encode(profile.preferredStrokes).utf8String
        entity.mainStrokeRaw = profile.mainStroke?.rawValue
        entity.distancePreferenceRaw = profile.distancePreference.rawValue
        entity.preferredDistanceUnitRaw = profile.preferredDistanceUnit.rawValue
        entity.profileIconTypeRaw = profile.profileIconType.rawValue
        entity.profileImageData = profile.profileImageData
        entity.profileIconName = profile.profileIconName
        entity.personalBestsJSON = try encoder.encode(profile.personalBests).utf8String
        entity.pbHistoryJSON = profile.pbHistory != nil ? try encoder.encode(profile.pbHistory!).utf8String : nil
        entity.cssHistoryJSON = profile.cssHistory != nil ? try encoder.encode(profile.cssHistory!).utf8String : nil
        entity.trainingGoalsJSON = try encoder.encode(profile.trainingGoals).utf8String
        entity.limitationsJSON = profile.limitations != nil ? try encoder.encode(profile.limitations!).utf8String : nil
        entity.createdAt = profile.createdAt
        entity.updatedAt = profile.updatedAt
        return entity
    }

    public func createTrainingNoteEntity(from note: TrainingNote, in context: NSManagedObjectContext) throws -> TrainingNoteEntity {
        let entity = TrainingNoteEntity(context: context)
        entity.userId = note.userId
        entity.date = note.date
        entity.strokeFocusRaw = try encoder.encode(note.strokeFocus).utf8String
        entity.techniqueFocusRaw = try encoder.encode(note.techniqueFocus).utf8String
        entity.notes = note.notes
        entity.llmInsights = note.llmInsights
        entity.createdAt = note.createdAt
        entity.updatedAt = note.updatedAt

        // Create goal entities and add via mutable set
        let goalsSet = entity.mutableSetValue(forKey: "goals")
        for goal in note.goals {
            let goalEntity = createGoalEntity(from: goal, in: context)
            goalsSet.add(goalEntity)
        }

        return entity
    }

    public func createGoalEntity(from goal: Goal, in context: NSManagedObjectContext) -> GoalEntity {
        let entity = GoalEntity(context: context)
        entity.id = goal.id
        entity.typeRaw = goal.type.rawValue
        entity.target = goal.target
        entity.strokeIdRaw = goal.strokeId?.rawValue
        entity.descriptionText = goal.description  // Renamed to avoid NSObject.description conflict
        entity.statusRaw = goal.status.rawValue
        entity.revisit = goal.revisit ?? false
        entity.metricsJSON = goal.metrics != nil ? try? encoder.encode(goal.metrics!).utf8String : nil
        entity.techniqueNodeId = goal.techniqueNodeId
        entity.coachingTips = goal.coachingTips
        entity.goalNotes = goal.notes
        entity.goalKindRaw = goal.goalKind?.rawValue
        entity.competitiveDrillSnapshotJSON = goal.competitiveMetricSnapshot != nil ? try? encoder.encode(goal.competitiveMetricSnapshot!).utf8String : nil
        entity.suggestedCuesJSON = goal.suggestedCues != nil ? try? encoder.encode(goal.suggestedCues!).utf8String : nil
        entity.createdAt = goal.createdAt
        entity.updatedAt = goal.updatedAt
        return entity
    }

    public func createWeeklyPlanEntity(from plan: WeeklyTrainingPlan, userId: String, in context: NSManagedObjectContext) throws -> WeeklyTrainingPlanEntity {
        let entity = WeeklyTrainingPlanEntity(context: context)
        // Mirror the domain id so `delete(planId:userId:)` and any other
        // backend agree on the identity of a plan. UUIDs would diverge on
        // every save and break the JSON-vs-Core-Data parity.
        entity.id = plan.idString
        entity.userId = userId
        entity.weekStartingDate = plan.weekStartingDate
        // Encode JSON directly to String (no base64)
        entity.overviewJSON = try encoder.encode(plan.overview).utf8String
        entity.scheduleJSON = try encoder.encode(plan.schedule).utf8String
        entity.weeklyGoalsJSON = plan.weeklyGoals != nil ? try encoder.encode(plan.weeklyGoals!).utf8String : nil
        entity.techniqueProgressPlanJSON = plan.techniqueProgressPlan != nil ? try encoder.encode(plan.techniqueProgressPlan!).utf8String : nil
        entity.notes = plan.notes
        entity.poolTypeRaw = plan.poolTypeRaw

        // Create session entities via mutable set
        let sessionsSet = entity.mutableSetValue(forKey: "detailedSessions")
        for session in plan.detailedSessions {
            let sessionEntity = createDetailedSessionEntity(from: session, in: context)
            sessionsSet.add(sessionEntity)
        }

        // Create dry land entities via mutable set
        if let dryLand = plan.dryLandProgram {
            let dryLandSet = entity.mutableSetValue(forKey: "dryLandProgram")
            for exercise in dryLand {
                let dryLandEntity = createDryLandEntity(from: exercise, in: context)
                dryLandSet.add(dryLandEntity)
            }
        }

        return entity
    }

    public func createDetailedSessionEntity(from session: DetailedSession, in context: NSManagedObjectContext) -> DetailedSessionEntity {
        let entity = DetailedSessionEntity(context: context)
        entity.id = session.id  // Use existing ID
        entity.sessionNumber = Int32(session.sessionNumber)
        entity.focus = session.focus
        // Encode JSON directly to String (no base64)
        entity.warmUpJSON = try? encoder.encode(session.warmUp).utf8String
        entity.drillSetJSON = try? encoder.encode(session.drillSet).utf8String
        entity.mainSetJSON = try? encoder.encode(session.mainSet).utf8String
        entity.secondarySetJSON = session.secondarySet != nil ? try? encoder.encode(session.secondarySet!).utf8String : nil
        entity.coolDownJSON = try? encoder.encode(session.coolDown).utf8String
        entity.techniqueFocus = session.techniqueFocus
        entity.techniqueFileRef = session.techniqueFileRef
        entity.addressesGoal = session.addressesGoal
        entity.sessionType = session.sessionType
        entity.progressionRationale = session.progressionRationale
        entity.sessionNotes = session.sessionNotes
        entity.scheduledDate = session.scheduledDate
        entity.timeOfDay = session.timeOfDay?.rawValue
        entity.isCompleted = session.isCompleted
        entity.isAssigned = session.isAssigned
        return entity
    }

    public func createDryLandEntity(from exercise: DryLandExercisePlan, in context: NSManagedObjectContext) -> DryLandExercisePlanEntity {
        let entity = DryLandExercisePlanEntity(context: context)
        entity.id = exercise.id  // Use existing ID
        entity.exercise = exercise.exercise
        entity.setsReps = exercise.setsReps
        entity.focus = exercise.focus
        entity.techniqueSupport = exercise.techniqueSupport
        entity.scheduledDate = exercise.scheduledDate
        entity.isAssigned = exercise.isAssigned
        entity.isCompleted = exercise.isCompleted
        return entity
    }

    public func createTechniqueMeasurementEntity(from measurement: TechniqueMeasurement, in context: NSManagedObjectContext) -> TechniqueMeasurementEntity {
        let entity = TechniqueMeasurementEntity(context: context)
        entity.id = measurement.id
        entity.userId = measurement.userId
        entity.date = measurement.date
        entity.timestamp = measurement.timestamp
        entity.strokeIdRaw = measurement.strokeId.rawValue
        entity.poolLength = Int32(measurement.poolLength)
        entity.distanceUnitRaw = measurement.distanceUnit.rawValue
        entity.strokeCount = Int32(measurement.strokeCount)
        entity.lapTime = measurement.lapTime
        entity.glideTime = measurement.glideTime != nil ? NSNumber(value: measurement.glideTime!) : nil
        entity.handPositionRaw = measurement.handPosition?.rawValue
        entity.kickPerStroke = measurement.kickPerStroke != nil ? NSNumber(value: Int32(measurement.kickPerStroke!)) : nil
        entity.effortZone = Int32(measurement.effortZone)
        entity.drillContext = measurement.drillContext
        entity.notes = measurement.notes
        entity.createdAt = measurement.createdAt
        entity.updatedAt = measurement.updatedAt
        return entity
    }

    public func createTimerSessionEntity(from session: TimerSession, in context: NSManagedObjectContext) throws -> TimerSessionEntity {
        let entity = TimerSessionEntity(context: context)
        entity.id = session.id
        entity.userId = session.userId
        entity.date = session.date
        entity.strokeIdRaw = session.strokeId.rawValue
        entity.poolLength = Int32(session.poolLength)
        entity.distanceUnitRaw = session.distanceUnit.rawValue
        entity.totalDistance = Int32(session.totalDistance)
        entity.splitsJSON = try encoder.encode(session.splits).utf8String
        entity.totalTime = session.totalTime
        entity.notes = session.notes
        entity.createdAt = session.createdAt
        entity.updatedAt = session.updatedAt
        return entity
    }
}

// MARK: - Core Data Repository Implementations

public actor CoreDataUserProfileRepository: UserProfileRepository {
    private let controller: CoreDataPersistenceController
    private let encoder = SwimNoteJSONEncoder()
    private let decoder = SwimNoteJSONDecoder()

    public init(controller: CoreDataPersistenceController) {
        self.controller = controller
    }

    public func listProfiles() async -> [UserProfile] {
        await MainActor.run {
            let context = controller.viewContext
            let fetchRequest = NSFetchRequest<UserProfileEntity>(entityName: "UserProfile")
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

            do {
                let entities = try context.fetch(fetchRequest)
                return entities.compactMap { try? $0.toUserProfile() }
            } catch {
                print("Error fetching profiles: \(error)")
                return []
            }
        }
    }

    public func profile(id: String) async -> UserProfile? {
        await MainActor.run {
            let context = controller.viewContext
            let fetchRequest = NSFetchRequest<UserProfileEntity>(entityName: "UserProfile")
            fetchRequest.predicate = NSPredicate(format: "id == %@", id)
            fetchRequest.fetchLimit = 1

            do {
                let entities = try context.fetch(fetchRequest)
                return entities.first.flatMap { try? $0.toUserProfile() }
            } catch {
                print("Error fetching profile: \(error)")
                return nil
            }
        }
    }

    public func save(_ profile: UserProfile) async throws {
        try await MainActor.run {
            let context = controller.viewContext

            // Check if entity exists
            let fetchRequest = NSFetchRequest<UserProfileEntity>(entityName: "UserProfile")
            fetchRequest.predicate = NSPredicate(format: "id == %@", profile.id)
            fetchRequest.fetchLimit = 1

            let existingEntity = (try? context.fetch(fetchRequest))?.first

            if let entity = existingEntity {
                // Update existing
                entity.name = profile.name
                entity.birthday = profile.birthday
                entity.sexRaw = profile.sex.rawValue
                entity.skillLevelRaw = profile.skillLevel.rawValue
                entity.weeklySessionTarget = Int32(profile.weeklySessionTarget)
                entity.preferredStrokesRaw = try? encoder.encode(profile.preferredStrokes).utf8String
                entity.mainStrokeRaw = profile.mainStroke?.rawValue
                entity.distancePreferenceRaw = profile.distancePreference.rawValue
                entity.preferredDistanceUnitRaw = profile.preferredDistanceUnit.rawValue
                entity.profileIconTypeRaw = profile.profileIconType.rawValue
                entity.profileImageData = profile.profileImageData
                entity.profileIconName = profile.profileIconName
                entity.personalBestsJSON = try? encoder.encode(profile.personalBests).utf8String
                entity.pbHistoryJSON = profile.pbHistory != nil ? try? encoder.encode(profile.pbHistory!).utf8String : nil
                entity.cssHistoryJSON = profile.cssHistory != nil ? try? encoder.encode(profile.cssHistory!).utf8String : nil
                entity.trainingGoalsJSON = try? encoder.encode(profile.trainingGoals).utf8String
                entity.limitationsJSON = profile.limitations != nil ? try? encoder.encode(profile.limitations!).utf8String : nil
                entity.updatedAt = profile.updatedAt
            } else {
                // Create new
                _ = try controller.createUserProfileEntity(from: profile, in: context)
            }

            try context.save()
        }
    }

    public func delete(id: String) async throws {
        try await MainActor.run {
            let context = controller.viewContext
            let fetchRequest = NSFetchRequest<UserProfileEntity>(entityName: "UserProfile")
            fetchRequest.predicate = NSPredicate(format: "id == %@", id)

            do {
                let entities = try context.fetch(fetchRequest)
                for entity in entities {
                    context.delete(entity)
                }
                try context.save()
            } catch {
                print("Error deleting profile: \(error)")
                throw error
            }
        }
    }

    public func activeProfileId() async -> String? {
        UserDefaults.standard.string(forKey: "activeProfileId")
    }

    public func setActiveProfile(id: String) async throws {
        UserDefaults.standard.set(id, forKey: "activeProfileId")
    }
}

public actor CoreDataTrainingNoteRepository: TrainingNoteRepository {
    private let controller: CoreDataPersistenceController
    private let encoder = SwimNoteJSONEncoder()
    private let decoder = SwimNoteJSONDecoder()

    public init(controller: CoreDataPersistenceController) {
        self.controller = controller
    }

    public func note(for userId: String, date: String) async -> TrainingNote? {
        await MainActor.run {
            let context = controller.viewContext
            let fetchRequest = NSFetchRequest<TrainingNoteEntity>(entityName: "TrainingNote")
            fetchRequest.predicate = NSPredicate(format: "userId == %@ AND date == %@", userId, date)
            fetchRequest.fetchLimit = 1

            do {
                let entities = try context.fetch(fetchRequest)
                return entities.first.flatMap { try? $0.toTrainingNote() }
            } catch {
                print("Error fetching note: \(error)")
                return nil
            }
        }
    }

    public func listNotes(for userId: String) async -> [TrainingNote] {
        await MainActor.run {
            let context = controller.viewContext
            let fetchRequest = NSFetchRequest<TrainingNoteEntity>(entityName: "TrainingNote")
            fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]

            do {
                let entities = try context.fetch(fetchRequest)
                return entities.compactMap { try? $0.toTrainingNote() }
            } catch {
                print("Error fetching notes: \(error)")
                return []
            }
        }
    }

    public func save(_ note: TrainingNote) async throws {
        try await MainActor.run {
            let context = controller.viewContext

            // Check if entity exists
            let fetchRequest = NSFetchRequest<TrainingNoteEntity>(entityName: "TrainingNote")
            fetchRequest.predicate = NSPredicate(format: "userId == %@ AND date == %@", note.userId, note.date)
            fetchRequest.fetchLimit = 1

            let existingEntity = (try? context.fetch(fetchRequest))?.first

            if let entity = existingEntity {
                // Update existing - delete old goals and create new ones
                entity.strokeFocusRaw = try? encoder.encode(note.strokeFocus).utf8String
                entity.techniqueFocusRaw = try? encoder.encode(note.techniqueFocus).utf8String
                entity.notes = note.notes
                entity.llmInsights = note.llmInsights
                entity.updatedAt = note.updatedAt

                // Delete existing goals using mutable set
                let goalsSet = entity.mutableSetValue(forKey: "goals")
                for goalEntity in goalsSet {
                    context.delete(goalEntity as! NSManagedObject)
                }
                goalsSet.removeAllObjects()

                // Create new goals and add to set
                for goal in note.goals {
                    let goalEntity = controller.createGoalEntity(from: goal, in: context)
                    goalsSet.add(goalEntity)
                }
            } else {
                // Create new
                _ = try controller.createTrainingNoteEntity(from: note, in: context)
            }

            try context.save()
        }
    }

    public func delete(userId: String, date: String) async throws {
        try await MainActor.run {
            let context = controller.viewContext
            let fetchRequest = NSFetchRequest<TrainingNoteEntity>(entityName: "TrainingNote")
            fetchRequest.predicate = NSPredicate(format: "userId == %@ AND date == %@", userId, date)

            do {
                let entities = try context.fetch(fetchRequest)
                for entity in entities {
                    context.delete(entity)
                }
                try context.save()
            } catch {
                print("Error deleting note: \(error)")
                throw error
            }
        }
    }
}

public actor CoreDataWeeklyPlanRepository: WeeklyPlanRepository {
    private let controller: CoreDataPersistenceController
    private let encoder = SwimNoteJSONEncoder()
    private let decoder = SwimNoteJSONDecoder()

    public init(controller: CoreDataPersistenceController) {
        self.controller = controller
    }

    public func listPlans(for userId: String) async -> [WeeklyTrainingPlan] {
        await MainActor.run {
            let context = controller.viewContext
            let fetchRequest = NSFetchRequest<WeeklyTrainingPlanEntity>(entityName: "WeeklyTrainingPlan")
            fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "weekStartingDate", ascending: false)]

            do {
                let entities = try context.fetch(fetchRequest)
                return entities.compactMap { try? $0.toWeeklyTrainingPlan() }
            } catch {
                print("Error fetching weekly plans: \(error)")
                return []
            }
        }
    }

    public func plan(for userId: String, weekStarting: String) async -> WeeklyTrainingPlan? {
        await MainActor.run {
            let context = controller.viewContext
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"

            guard let date = formatter.date(from: weekStarting) else { return nil }

            let fetchRequest = NSFetchRequest<WeeklyTrainingPlanEntity>(entityName: "WeeklyTrainingPlan")
            fetchRequest.predicate = NSPredicate(format: "userId == %@ AND weekStartingDate == %@", userId, date as NSDate)
            fetchRequest.fetchLimit = 1

            do {
                let entities = try context.fetch(fetchRequest)
                return entities.first.flatMap { try? $0.toWeeklyTrainingPlan() }
            } catch {
                print("Error fetching weekly plan: \(error)")
                return nil
            }
        }
    }

    public func sessionsForDate(for userId: String, date: String) async -> [DetailedSession] {
        await MainActor.run {
            let context = controller.viewContext
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"

            guard let searchDate = formatter.date(from: date) else { return [] }

            // Use indexed fetch for scheduledDate
            let fetchRequest = NSFetchRequest<DetailedSessionEntity>(entityName: "DetailedSession")
            fetchRequest.predicate = NSPredicate(
                format: "scheduledDate == %@ AND weeklyPlan.userId == %@",
                searchDate as NSDate,
                userId
            )
            // Stable secondary sort by sessionNumber; primary order applied in Swift
            // because Core Data would sort the raw `timeOfDay` strings
            // lexicographically ("afternoon" < "evening" < "morning"), which is
            // not the natural morning→afternoon→evening order we want.
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "sessionNumber", ascending: true)]

            do {
                let entities = try context.fetch(fetchRequest)
                let sessions = entities.compactMap { try? $0.toDetailedSession() }
                return sessions.sorted { lhs, rhs in
                    let l = lhs.timeOfDay?.sortOrder ?? Int.max
                    let r = rhs.timeOfDay?.sortOrder ?? Int.max
                    if l != r { return l < r }
                    return lhs.sessionNumber < rhs.sessionNumber
                }
            } catch {
                print("Error fetching sessions by date: \(error)")
                return []
            }
        }
    }

    public func save(_ plan: WeeklyTrainingPlan, for userId: String) async throws {
        try await MainActor.run {
            let context = controller.viewContext

            // Check if entity exists by weekStartingDate
            let fetchRequest = NSFetchRequest<WeeklyTrainingPlanEntity>(entityName: "WeeklyTrainingPlan")
            if let weekDate = plan.weekStartingDate {
                fetchRequest.predicate = NSPredicate(format: "userId == %@ AND weekStartingDate == %@", userId, weekDate as NSDate)
            } else {
                // If no weekStartingDate, check by existing sessions
                fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
            }
            fetchRequest.fetchLimit = 1

            let existingEntity = (try? context.fetch(fetchRequest))?.first

            if let entity = existingEntity {
                // Update existing
                // Re-stamp the id so a row created before P0-1D (when ids were
                // random UUIDs) is migrated to the deterministic plan.idString
                // on the next save. After this re-stamp `delete(planId:)` can
                // find the row by the same string both backends use.
                entity.id = plan.idString
                entity.overviewJSON = try? encoder.encode(plan.overview).utf8String
                entity.scheduleJSON = try? encoder.encode(plan.schedule).utf8String
                entity.weeklyGoalsJSON = plan.weeklyGoals != nil ? try? encoder.encode(plan.weeklyGoals!).utf8String : nil
                entity.techniqueProgressPlanJSON = plan.techniqueProgressPlan != nil ? try? encoder.encode(plan.techniqueProgressPlan!).utf8String : nil
                entity.notes = plan.notes
                entity.poolTypeRaw = plan.poolTypeRaw
                entity.weekStartingDate = plan.weekStartingDate

                // Delete existing sessions using mutable set
                let sessionsSet = entity.mutableSetValue(forKey: "detailedSessions")
                for sessionEntity in sessionsSet {
                    context.delete(sessionEntity as! NSManagedObject)
                }
                sessionsSet.removeAllObjects()

                // Delete existing dry land using mutable set
                let dryLandSet = entity.mutableSetValue(forKey: "dryLandProgram")
                for dryLandEntity in dryLandSet {
                    context.delete(dryLandEntity as! NSManagedObject)
                }
                dryLandSet.removeAllObjects()

                // Create new sessions and add to set
                for session in plan.detailedSessions {
                    let sessionEntity = controller.createDetailedSessionEntity(from: session, in: context)
                    sessionsSet.add(sessionEntity)
                }

                // Create new dry land and add to set
                if let dryLand = plan.dryLandProgram {
                    for exercise in dryLand {
                        let dryLandEntity = controller.createDryLandEntity(from: exercise, in: context)
                        dryLandSet.add(dryLandEntity)
                    }
                }
            } else {
                // Create new
                _ = try controller.createWeeklyPlanEntity(from: plan, userId: userId, in: context)
            }

            try context.save()
        }
    }

    public func delete(planId: String, userId: String) async throws {
        try await MainActor.run {
            let context = controller.viewContext
            let fetchRequest = NSFetchRequest<WeeklyTrainingPlanEntity>(entityName: "WeeklyTrainingPlan")
            fetchRequest.predicate = NSPredicate(format: "id == %@ AND userId == %@", planId, userId)

            do {
                let entities = try context.fetch(fetchRequest)
                for entity in entities {
                    context.delete(entity)
                }
                try context.save()
            } catch {
                print("Error deleting weekly plan: \(error)")
                throw error
            }
        }
    }
}

// MARK: - Technique Measurement Repository Protocol

public protocol TechniqueMeasurementRepository: Sendable {
    func list(for userId: String) async -> [TechniqueMeasurement]
    func list(for userId: String, date: String) async -> [TechniqueMeasurement]
    func save(_ measurement: TechniqueMeasurement) async throws
    func delete(id: String) async throws
}

// MARK: - Core Data Technique Measurement Repository

public actor CoreDataTechniqueMeasurementRepository: TechniqueMeasurementRepository {
    private let controller: CoreDataPersistenceController

    public init(controller: CoreDataPersistenceController) {
        self.controller = controller
    }

    public func list(for userId: String) async -> [TechniqueMeasurement] {
        await MainActor.run {
            let context = controller.viewContext
            let fetchRequest = NSFetchRequest<TechniqueMeasurementEntity>(entityName: "TechniqueMeasurement")
            fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]

            do {
                let entities = try context.fetch(fetchRequest)
                return entities.map { $0.toTechniqueMeasurement() }
            } catch {
                print("Error fetching measurements: \(error)")
                return []
            }
        }
    }

    public func list(for userId: String, date: String) async -> [TechniqueMeasurement] {
        await MainActor.run {
            let context = controller.viewContext
            let fetchRequest = NSFetchRequest<TechniqueMeasurementEntity>(entityName: "TechniqueMeasurement")
            fetchRequest.predicate = NSPredicate(format: "userId == %@ AND date == %@", userId, date)
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]

            do {
                let entities = try context.fetch(fetchRequest)
                return entities.map { $0.toTechniqueMeasurement() }
            } catch {
                print("Error fetching measurements for date: \(error)")
                return []
            }
        }
    }

    public func save(_ measurement: TechniqueMeasurement) async throws {
        try await MainActor.run {
            let context = controller.viewContext

            // Check if entity exists
            let fetchRequest = NSFetchRequest<TechniqueMeasurementEntity>(entityName: "TechniqueMeasurement")
            fetchRequest.predicate = NSPredicate(format: "id == %@", measurement.id)
            fetchRequest.fetchLimit = 1

            let existingEntity = (try? context.fetch(fetchRequest))?.first

            if let entity = existingEntity {
                // Update existing
                entity.strokeIdRaw = measurement.strokeId.rawValue
                entity.poolLength = Int32(measurement.poolLength)
                entity.distanceUnitRaw = measurement.distanceUnit.rawValue
                entity.strokeCount = Int32(measurement.strokeCount)
                entity.lapTime = measurement.lapTime
                entity.glideTime = measurement.glideTime != nil ? NSNumber(value: measurement.glideTime!) : nil
                entity.handPositionRaw = measurement.handPosition?.rawValue
                entity.kickPerStroke = measurement.kickPerStroke != nil ? NSNumber(value: Int32(measurement.kickPerStroke!)) : nil
                entity.effortZone = Int32(measurement.effortZone)
                entity.drillContext = measurement.drillContext
                entity.notes = measurement.notes
                entity.updatedAt = measurement.updatedAt
            } else {
                // Create new
                _ = controller.createTechniqueMeasurementEntity(from: measurement, in: context)
            }

            try context.save()
        }
    }

    public func delete(id: String) async throws {
        try await MainActor.run {
            let context = controller.viewContext
            let fetchRequest = NSFetchRequest<TechniqueMeasurementEntity>(entityName: "TechniqueMeasurement")
            fetchRequest.predicate = NSPredicate(format: "id == %@", id)

            do {
                let entities = try context.fetch(fetchRequest)
                for entity in entities {
                    context.delete(entity)
                }
                try context.save()
            } catch {
                print("Error deleting measurement: \(error)")
                throw error
            }
        }
    }
}

// MARK: - Timer Session Repository Protocol

public protocol TimerSessionRepository: Sendable {
    func list(for userId: String) async -> [TimerSession]
    func list(for userId: String, date: String) async -> [TimerSession]
    func save(_ session: TimerSession) async throws
    func delete(id: String) async throws
}

// MARK: - Core Data Timer Session Repository

public actor CoreDataTimerSessionRepository: TimerSessionRepository {
    private let controller: CoreDataPersistenceController

    public init(controller: CoreDataPersistenceController) {
        self.controller = controller
    }

    public func list(for userId: String) async -> [TimerSession] {
        await MainActor.run {
            let context = controller.viewContext
            let fetchRequest = NSFetchRequest<TimerSessionEntity>(entityName: "TimerSession")
            fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

            do {
                let entities = try context.fetch(fetchRequest)
                return entities.compactMap { try? $0.toTimerSession() }
            } catch {
                print("Error fetching timer sessions: \(error)")
                return []
            }
        }
    }

    public func list(for userId: String, date: String) async -> [TimerSession] {
        await MainActor.run {
            let context = controller.viewContext
            let fetchRequest = NSFetchRequest<TimerSessionEntity>(entityName: "TimerSession")
            fetchRequest.predicate = NSPredicate(format: "userId == %@ AND date == %@", userId, date)
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

            do {
                let entities = try context.fetch(fetchRequest)
                return entities.compactMap { try? $0.toTimerSession() }
            } catch {
                print("Error fetching timer sessions for date: \(error)")
                return []
            }
        }
    }

    public func save(_ session: TimerSession) async throws {
        try await MainActor.run {
            let context = controller.viewContext

            // Check if entity exists
            let fetchRequest = NSFetchRequest<TimerSessionEntity>(entityName: "TimerSession")
            fetchRequest.predicate = NSPredicate(format: "id == %@", session.id)
            fetchRequest.fetchLimit = 1

            let existingEntity = (try? context.fetch(fetchRequest))?.first

            if let entity = existingEntity {
                // Update existing
                entity.strokeIdRaw = session.strokeId.rawValue
                entity.poolLength = Int32(session.poolLength)
                entity.distanceUnitRaw = session.distanceUnit.rawValue
                entity.totalDistance = Int32(session.totalDistance)
                entity.splitsJSON = try controller.encoder.encode(session.splits).utf8String
                entity.totalTime = session.totalTime
                entity.notes = session.notes
                entity.updatedAt = session.updatedAt
            } else {
                // Create new
                _ = try controller.createTimerSessionEntity(from: session, in: context)
            }

            try context.save()
        }
    }

    public func delete(id: String) async throws {
        try await MainActor.run {
            let context = controller.viewContext
            let fetchRequest = NSFetchRequest<TimerSessionEntity>(entityName: "TimerSession")
            fetchRequest.predicate = NSPredicate(format: "id == %@", id)

            do {
                let entities = try context.fetch(fetchRequest)
                for entity in entities {
                    context.delete(entity)
                }
                try context.save()
            } catch {
                print("Error deleting timer session: \(error)")
                throw error
            }
        }
    }
}

#else
// Fallback implementations when Core Data is not available
public final class CoreDataPersistenceController: @unchecked Sendable {
    public init(modelName: String = "SwimNote", storageURL: URL? = nil) {}
    public func load() async throws {
        throw SwimNotePersistenceError.cloudKitStoreUnavailable
    }
}

public actor CoreDataUserProfileRepository: UserProfileRepository {
    public init(controller: CoreDataPersistenceController) {}
    public func listProfiles() async -> [UserProfile] { [] }
    public func profile(id: String) async -> UserProfile? { nil }
    public func save(_ profile: UserProfile) async throws {
        throw SwimNotePersistenceError.cloudKitStoreUnavailable
    }
    public func delete(id: String) async throws {
        throw SwimNotePersistenceError.cloudKitStoreUnavailable
    }
    public func activeProfileId() async -> String? { nil }
    public func setActiveProfile(id: String) async throws {}
}

public actor CoreDataTrainingNoteRepository: TrainingNoteRepository {
    public init(controller: CoreDataPersistenceController) {}
    public func note(for userId: String, date: String) async -> TrainingNote? { nil }
    public func listNotes(for userId: String) async -> [TrainingNote] { [] }
    public func save(_ note: TrainingNote) async throws {
        throw SwimNotePersistenceError.cloudKitStoreUnavailable
    }
    public func delete(userId: String, date: String) async throws {
        throw SwimNotePersistenceError.cloudKitStoreUnavailable
    }
}

public actor CoreDataWeeklyPlanRepository: WeeklyPlanRepository {
    public init(controller: CoreDataPersistenceController) {}
    public func listPlans(for userId: String) async -> [WeeklyTrainingPlan] { [] }
    public func plan(for userId: String, weekStarting: String) async -> WeeklyTrainingPlan? { nil }
    public func sessionsForDate(for userId: String, date: String) async -> [DetailedSession] { [] }
    public func save(_ plan: WeeklyTrainingPlan, for userId: String) async throws {
        throw SwimNotePersistenceError.cloudKitStoreUnavailable
    }
    public func delete(planId: String, userId: String) async throws {
        throw SwimNotePersistenceError.cloudKitStoreUnavailable
    }
}

public actor CoreDataTechniqueMeasurementRepository: TechniqueMeasurementRepository {
    public init(controller: CoreDataPersistenceController) {}
    public func list(for userId: String) async -> [TechniqueMeasurement] { [] }
    public func list(for userId: String, date: String) async -> [TechniqueMeasurement] { [] }
    public func save(_ measurement: TechniqueMeasurement) async throws {
        throw SwimNotePersistenceError.cloudKitStoreUnavailable
    }
    public func delete(id: String) async throws {
        throw SwimNotePersistenceError.cloudKitStoreUnavailable
    }
}

public actor CoreDataTimerSessionRepository: TimerSessionRepository {
    public init(controller: CoreDataPersistenceController) {}
    public func list(for userId: String) async -> [TimerSession] { [] }
    public func list(for userId: String, date: String) async -> [TimerSession] { [] }
    public func save(_ session: TimerSession) async throws {
        throw SwimNotePersistenceError.cloudKitStoreUnavailable
    }
    public func delete(id: String) async throws {
        throw SwimNotePersistenceError.cloudKitStoreUnavailable
    }
}
#endif

// MARK: - JSON to Core Data Migration

public struct CoreDataMigration: Sendable {
    private let controller: CoreDataPersistenceController
    private let appSupportURL: URL
    private let jsonProfileRepo: JSONUserProfileRepository
    private let jsonNoteRepo: JSONTrainingNoteRepository
    private let jsonPlanRepo: JSONWeeklyPlanRepository
    private let fileAccessor: any FileAccessorProviding

    public init(
        controller: CoreDataPersistenceController,
        appSupportURL: URL,
        fileAccessor: any FileAccessorProviding = DefaultFileAccessor()
    ) {
        self.controller = controller
        self.appSupportURL = appSupportURL
        self.fileAccessor = fileAccessor
        self.jsonProfileRepo = JSONUserProfileRepository(
            configDirectory: appSupportURL.appendingPathComponent("config"),
            fileAccessor: fileAccessor
        )
        self.jsonNoteRepo = JSONTrainingNoteRepository(
            notesDirectory: appSupportURL.appendingPathComponent("notes"),
            fileAccessor: fileAccessor
        )
        self.jsonPlanRepo = JSONWeeklyPlanRepository(
            plansDirectory: appSupportURL.appendingPathComponent("weekly-plans")
        )
    }

    public func migrateAll() async throws {
        #if canImport(CoreData)
        print("Starting Core Data migration from JSON files...")

        // Clear old data if this is a re-migration (due to encoding fix)
        let migrationVersion = UserDefaults.standard.integer(forKey: "coreDataMigrationVersion")
        if migrationVersion < 2 {
            print("Clearing old Core Data data for re-migration...")
            await clearAllData()
        }

        // Migrate profiles
        let profiles = await jsonProfileRepo.listProfiles()
        print("Found \(profiles.count) profiles to migrate")

        let coreDataProfileRepo = CoreDataUserProfileRepository(controller: controller)
        for profile in profiles {
            try await coreDataProfileRepo.save(profile)
            print("Migrated profile: \(profile.name)")
        }

        // Migrate the active-profile pointer. JSON stored it in
        // `config/active_profile.json`, but the Core Data repo reads
        // UserDefaults["activeProfileId"]. Without copying it across the user
        // would land back in profile selection on next launch.
        if let activeId = await jsonProfileRepo.activeProfileId() {
            try await coreDataProfileRepo.setActiveProfile(id: activeId)
            print("Migrated active profile id: \(activeId)")
        }

        // Migrate notes for each profile
        let coreDataNoteRepo = CoreDataTrainingNoteRepository(controller: controller)
        for profile in profiles {
            let notes = await jsonNoteRepo.listNotes(for: profile.id)
            print("Found \(notes.count) notes for profile \(profile.name)")
            for note in notes {
                try await coreDataNoteRepo.save(note)
            }
        }

        // Migrate weekly plans for each profile
        let coreDataPlanRepo = CoreDataWeeklyPlanRepository(controller: controller)
        for profile in profiles {
            let plans = await jsonPlanRepo.listPlans(for: profile.id)
            print("Found \(plans.count) weekly plans for profile \(profile.name)")
            for plan in plans {
                try await coreDataPlanRepo.save(plan, for: profile.id)
            }
        }

        // Migration succeeded — drop the JSON sources of truth so we don't
        // keep stale dual data on disk that could diverge from Core Data.
        cleanupJSONSources(profileIds: profiles.map(\.id))

        // Mark migration complete with version
        UserDefaults.standard.set(2, forKey: "coreDataMigrationVersion")
        print("Core Data migration completed successfully")
        #else
        throw SwimNotePersistenceError.cloudKitStoreUnavailable
        #endif
    }

    /// Removes the JSON files that the Core Data backends have superseded:
    /// `config/active_profile.json`, `notes/<profileId>/`, and
    /// `weekly-plans/<profileId>/` for each migrated profile.
    /// Errors are logged but not thrown — cleanup is best-effort and must
    /// never undo a successful migration.
    private func cleanupJSONSources(profileIds: [String]) {
        let activeProfileFile = appSupportURL
            .appendingPathComponent("config")
            .appendingPathComponent("active_profile.json")
        do {
            try fileAccessor.remove(at: activeProfileFile)
        } catch {
            print("Cleanup: failed to remove active_profile.json: \(error)")
        }

        let notesRoot = appSupportURL.appendingPathComponent("notes")
        let plansRoot = appSupportURL.appendingPathComponent("weekly-plans")
        for id in profileIds {
            do {
                try fileAccessor.remove(at: notesRoot.appendingPathComponent(id))
            } catch {
                print("Cleanup: failed to remove notes/\(id): \(error)")
            }
            do {
                try fileAccessor.remove(at: plansRoot.appendingPathComponent(id))
            } catch {
                print("Cleanup: failed to remove weekly-plans/\(id): \(error)")
            }
        }
    }

    /// Internal access so tests can verify every entity is in the wipe list.
    /// Production callers use it via `migrateAll()`.
    internal func clearAllData() async {
        await MainActor.run {
            let context = controller.viewContext

            // Must list every entity in the .xcdatamodel — anything missing
            // here leaves orphan rows after a re-migration. Keep this list in
            // sync with SwimNote.xcdatamodel.
            let entities = [
                "UserProfile",
                "TrainingNote",
                "Goal",
                "WeeklyTrainingPlan",
                "DetailedSession",
                "DryLandExercisePlan",
                "TechniqueMeasurement",
                "TimerSession",
            ]
            for entityName in entities {
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                _ = try? context.execute(deleteRequest)
            }
            try? context.save()
        }
    }

    public static func needsMigration() -> Bool {
        // Reset migration due to encoding fix (base64 -> utf8)
        let migrationVersion = UserDefaults.standard.integer(forKey: "coreDataMigrationVersion")
        let currentVersion = 2  // v2: utf8 encoding for all JSON fields
        return migrationVersion < currentVersion
    }
}
