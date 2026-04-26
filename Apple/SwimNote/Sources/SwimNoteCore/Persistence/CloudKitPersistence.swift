import Foundation

#if canImport(CoreData)
import CoreData

public final class CloudKitPersistenceController: @unchecked Sendable {
    public let container: NSPersistentCloudKitContainer

    public init(containerName: String = "SwimNote") {
        container = NSPersistentCloudKitContainer(name: containerName)
        let description = container.persistentStoreDescriptions.first
        description?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        description?.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: "iCloud.com.swimnote.app"
        )
    }

    public func load() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            container.loadPersistentStores { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    self.container.viewContext.automaticallyMergesChangesFromParent = true
                    continuation.resume()
                }
            }
        }
    }
}
#else
public final class CloudKitPersistenceController: @unchecked Sendable {
    public init(containerName: String = "SwimNote") {}

    public func load() async throws {
        throw SwimNotePersistenceError.cloudKitStoreUnavailable
    }
}
#endif

public struct CloudKitPersistenceReadiness: Sendable, Equatable {
    public var usesPersistentHistoryTracking: Bool
    public var usesRemoteChangeNotifications: Bool
    public var cloudKitContainerIdentifier: String

    public init(
        usesPersistentHistoryTracking: Bool = true,
        usesRemoteChangeNotifications: Bool = true,
        cloudKitContainerIdentifier: String = "iCloud.com.swimnote.app"
    ) {
        self.usesPersistentHistoryTracking = usesPersistentHistoryTracking
        self.usesRemoteChangeNotifications = usesRemoteChangeNotifications
        self.cloudKitContainerIdentifier = cloudKitContainerIdentifier
    }
}
