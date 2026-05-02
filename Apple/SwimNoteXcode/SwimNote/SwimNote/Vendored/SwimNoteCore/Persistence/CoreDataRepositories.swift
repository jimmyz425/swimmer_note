@preconcurrency import Foundation
#if canImport(CoreData)
import CoreData
#endif

// MARK: - Core Data Persistence Controller

#if canImport(CoreData)
@MainActor
public final class CoreDataPersistenceController: Sendable {
    public let container: NSPersistentContainer
    private let encoder = SwimNoteJSONEncoder()
    private let decoder = SwimNoteJSONDecoder()

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
                    // For development: if migration fails, delete the incompatible store
                    let nsError = error as NSError
                    if nsError.code == 134140 || nsError.code == NSMigrationError || nsError.code == NSMigrationMissingSourceModelError {
                        print("CoreData migration failed. Deleting incompatible store and recreating...")
                        // Delete the existing store file
                        if let storeDescription = self.container.persistentStoreDescriptions.first,
                           let storeURL = storeDescription.url {
                            try? FileManager.default.removeItem(at: storeURL)
                            // Also delete related files (-shm, -wal)
                            let shmURL = storeURL.deletingLastPathComponent().appendingPathComponent(storeURL.lastPathComponent + "-shm")
                            let walURL = storeURL.deletingLastPathComponent().appendingPathComponent(storeURL.lastPathComponent + "-wal")
                            try? FileManager.default.removeItem(at: shmURL)
                            try? FileManager.default.removeItem(at: walURL)
                        }
                        // Try loading again
                        self.container.loadPersistentStores { _, retryError in
                            if let retryError {
                                continuation.resume(throwing: retryError)
                            } else {
                                self.container.viewContext.automaticallyMergesChangesFromParent = true
                                self.container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
                                continuation.resume()
                            }
                        }
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
        entity.competitiveDrillSnapshotJSON = goal.competitiveDrillSnapshot != nil ? try? encoder.encode(goal.competitiveDrillSnapshot!).utf8String : nil
        entity.createdAt = goal.createdAt
        entity.updatedAt = goal.updatedAt
        return entity
    }

    public func createWeeklyPlanEntity(from plan: WeeklyTrainingPlan, userId: String, in context: NSManagedObjectContext) throws -> WeeklyTrainingPlanEntity {
        let entity = WeeklyTrainingPlanEntity(context: context)
        entity.id = UUID().uuidString
        entity.userId = userId
        entity.weekStartingDate = plan.weekStartingDate
        // Encode JSON directly to String (no base64)
        entity.overviewJSON = try encoder.encode(plan.overview).utf8String
        entity.scheduleJSON = try encoder.encode(plan.schedule).utf8String
        entity.weeklyGoalsJSON = plan.weeklyGoals != nil ? try encoder.encode(plan.weeklyGoals!).utf8String : nil
        entity.techniqueProgressPlanJSON = plan.techniqueProgressPlan != nil ? try encoder.encode(plan.techniqueProgressPlan!).utf8String : nil
        entity.notes = plan.notes
        entity.poolTypeRaw = plan.poolTypeRaw

        // Create session entities via mutable setol,kmj q
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

    public func sessionForDate(for userId: String, date: String) async -> DetailedSession? {
        await MainActor.run {
            let context = controller.viewContext
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"

            guard let searchDate = formatter.date(from: date) else { return nil }

            // Use indexed fetch for scheduledDate
            let fetchRequest = NSFetchRequest<DetailedSessionEntity>(entityName: "DetailedSession")
            fetchRequest.predicate = NSPredicate(
                format: "scheduledDate == %@ AND weeklyPlan.userId == %@",
                searchDate as NSDate,
                userId
            )
            fetchRequest.fetchLimit = 1

            do {
                let entities = try context.fetch(fetchRequest)
                return entities.first.flatMap { try? $0.toDetailedSession() }
            } catch {
                print("Error fetching session by date: \(error)")
                return nil
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
    public func sessionForDate(for userId: String, date: String) async -> DetailedSession? { nil }
    public func save(_ plan: WeeklyTrainingPlan, for userId: String) async throws {
        throw SwimNotePersistenceError.cloudKitStoreUnavailable
    }
    public func delete(planId: String, userId: String) async throws {
        throw SwimNotePersistenceError.cloudKitStoreUnavailable
    }
}
#endif

// MARK: - JSON to Core Data Migration

public struct CoreDataMigration: Sendable {
    private let controller: CoreDataPersistenceController
    private let jsonProfileRepo: JSONUserProfileRepository
    private let jsonNoteRepo: JSONTrainingNoteRepository
    private let jsonPlanRepo: JSONWeeklyPlanRepository

    public init(
        controller: CoreDataPersistenceController,
        appSupportURL: URL
    ) {
        self.controller = controller
        self.jsonProfileRepo = JSONUserProfileRepository(
            configDirectory: appSupportURL.appendingPathComponent("config")
        )
        self.jsonNoteRepo = JSONTrainingNoteRepository(
            notesDirectory: appSupportURL.appendingPathComponent("notes")
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

        // Mark migration complete with version
        UserDefaults.standard.set(2, forKey: "coreDataMigrationVersion")
        print("Core Data migration completed successfully")
        #else
        throw SwimNotePersistenceError.cloudKitStoreUnavailable
        #endif
    }

    private func clearAllData() async {
        await MainActor.run {
            let context = controller.viewContext

            // Delete all entities
            let entities = ["UserProfile", "TrainingNote", "Goal", "WeeklyTrainingPlan", "DetailedSession", "DryLandExercisePlan"]
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
