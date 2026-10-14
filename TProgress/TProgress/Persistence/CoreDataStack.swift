import Foundation
import CoreData

/// Owns the single persistent container. Everything in the app reads and writes
/// through `viewContext` on the main actor; the dataset is small enough that a
/// background context would add risk without buying anything.
final class CoreDataStack {

    static let shared = CoreDataStack()

    let container: NSPersistentContainer

    var context: NSManagedObjectContext { container.viewContext }

    private init() {
        container = NSPersistentContainer(name: "TProgress")

        if let description = container.persistentStoreDescriptions.first {
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
        }

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }

        if loadError != nil {
            // A store that cannot be opened is worse than an empty one. Rebuild
            // it from scratch rather than refusing to launch.
            Self.destroyStores(for: container)
            container.loadPersistentStores { _, error in
                loadError = error
            }
        }

        if loadError != nil {
            // Last resort: run against memory so the interface still comes up.
            let description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            container.persistentStoreDescriptions = [description]
            container.loadPersistentStores { _, _ in }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.undoManager = nil
        container.viewContext.retainsRegisteredObjects = false
    }

    private static func destroyStores(for container: NSPersistentContainer) {
        let coordinator = container.persistentStoreCoordinator
        for description in container.persistentStoreDescriptions {
            guard let url = description.url else { continue }
            try? coordinator.destroyPersistentStore(at: url, ofType: description.type, options: nil)
        }
    }

    // MARK: - Saving

    func save() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            context.rollback()
        }
    }

    /// Mutates on the main context and commits in one step.
    func write(_ changes: (NSManagedObjectContext) -> Void) {
        changes(context)
        save()
    }

    // MARK: - Fetching

    func fetch<T: NSManagedObject>(
        _ type: T.Type,
        predicate: NSPredicate? = nil,
        sortBy: [NSSortDescriptor] = [],
        limit: Int? = nil
    ) -> [T] {
        let request = NSFetchRequest<T>(entityName: String(describing: type))
        request.predicate = predicate
        request.sortDescriptors = sortBy
        if let limit { request.fetchLimit = limit }
        return (try? context.fetch(request)) ?? []
    }

    func count<T: NSManagedObject>(_ type: T.Type, predicate: NSPredicate? = nil) -> Int {
        let request = NSFetchRequest<T>(entityName: String(describing: type))
        request.predicate = predicate
        return (try? context.count(for: request)) ?? 0
    }

    func delete(_ object: NSManagedObject) {
        context.delete(object)
        save()
    }
}

// MARK: - Shared sort descriptors

enum TPSort {

    static let newestPost = NSSortDescriptor(key: "createdAt", ascending: false)
    static let oldestPost = NSSortDescriptor(key: "createdAt", ascending: true)
    static let newestMessage = NSSortDescriptor(key: "lastMessageAt", ascending: false)
    static let byName = NSSortDescriptor(key: "name", ascending: true)
    static let byDisplayName = NSSortDescriptor(key: "displayName", ascending: true)
    static let byOrder = NSSortDescriptor(key: "order", ascending: true)
}
