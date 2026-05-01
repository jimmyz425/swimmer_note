@preconcurrency import Foundation
#if canImport(CoreData)
import CoreData
#endif

// MARK: - Core Data Support (Optional, requires Xcode model file)

// NOTE: Core Data integration requires:
// 1. SwimNote.xcdatamodeld model file in Xcode project
// 2. Code generation enabled for entity classes
// 3. Swift 6 concurrency adaptations
//
// For now, JSON repositories remain the default. Enable Core Data in Settings
// once model file is properly configured in Xcode.

#if canImport(CoreData)
/// Core Data persistence controller placeholder
/// Full implementation requires model configuration in Xcode
@MainActor
public final class CoreDataPersistenceController: Sendable {
    public let container: NSPersistentContainer

    public init(modelName: String = "SwimNote", storageURL: URL? = nil) {
        // Load model from bundle
        guard let modelURL = Bundle.main.url(forResource: modelName, withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: modelURL) else {
            // Create minimal empty model as fallback
            let emptyModel = NSManagedObjectModel()
            container = NSPersistentContainer(name: modelName, managedObjectModel: emptyModel)
            return
        }

        container = NSPersistentContainer(name: modelName, managedObjectModel: model)

        if let storeURL = storageURL {
            let description = NSPersistentStoreDescription(url: storeURL)
            container.persistentStoreDescriptions = [description]
        }
    }

    public func load() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            container.loadPersistentStores { _, error in
                if let error {
                    continuation.resume(throwing: error)
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
}

/// Stub implementations - full implementations require Xcode model configuration
public actor CoreDataUserProfileRepository: UserProfileRepository {
    private let controller: CoreDataPersistenceController

    public init(controller: CoreDataPersistenceController) {
        self.controller = controller
    }

    public func listProfiles() async -> [UserProfile] {
        // TODO: Implement with Core Data once model is configured
        return []
    }

    public func profile(id: String) async -> UserProfile? {
        // TODO: Implement with Core Data once model is configured
        return nil
    }

    public func save(_ profile: UserProfile) async throws {
        // TODO: Implement with Core Data once model is configured
        throw SwimNotePersistenceError.cloudKitStoreUnavailable
    }

    public func delete(id: String) async throws {
        // TODO: Implement with Core Data once model is configured
        throw SwimNotePersistenceError.cloudKitStoreUnavailable
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

    public init(controller: CoreDataPersistenceController) {
        self.controller = controller
    }

    public func note(for userId: String, date: String) async -> TrainingNote? {
        // TODO: Implement with Core Data once model is configured
        return nil
    }

    public func listNotes(for userId: String) async -> [TrainingNote] {
        // TODO: Implement with Core Data once model is configured
        return []
    }

    public func save(_ note: TrainingNote) async throws {
        // TODO: Implement with Core Data once model is configured
        throw SwimNotePersistenceError.cloudKitStoreUnavailable
    }

    public func delete(userId: String, date: String) async throws {
        // TODO: Implement with Core Data once model is configured
        throw SwimNotePersistenceError.cloudKitStoreUnavailable
    }
}

public actor CoreDataWeeklyPlanRepository: WeeklyPlanRepository {
    private let controller: CoreDataPersistenceController

    public init(controller: CoreDataPersistenceController) {
        self.controller = controller
    }

    public func listPlans(for userId: String) async -> [WeeklyTrainingPlan] {
        // TODO: Implement with Core Data once model is configured
        return []
    }

    public func plan(for userId: String, weekStarting: String) async -> WeeklyTrainingPlan? {
        // TODO: Implement with Core Data once model is configured
        return nil
    }

    public func sessionForDate(for userId: String, date: String) async -> DetailedSession? {
        // TODO: Implement with Core Data indexed lookup once model is configured
        return nil
    }

    public func save(_ plan: WeeklyTrainingPlan, for userId: String) async throws {
        // TODO: Implement with Core Data once model is configured
        throw SwimNotePersistenceError.cloudKitStoreUnavailable
    }

    public func delete(planId: String, userId: String) async throws {
        // TODO: Implement with Core Data once model is configured
        throw SwimNotePersistenceError.cloudKitStoreUnavailable
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

// MARK: - Migration placeholder

/// Migration from JSON to Core Data (to be implemented once model is configured)
public struct CoreDataMigration {
    public init() {}

    public func migrateAll() async throws {
        // TODO: Implement migration once Core Data model is configured
        // This would read JSON files and populate Core Data entities
    }
}