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

        // Taken before the store is opened, so it survives whatever opening does
        // to it — including the rebuild below.
        Self.backUpStoreIfPresent()

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

    // MARK: - Backup
    //
    // A store that cannot be opened is rebuilt from nothing, which is the right
    // call for the interface and the wrong one for the log — that file is the
    // whole of what this app keeps. Copying it before every launch turns "a bad
    // migration" from a permanent loss into a file sitting on disk.
    //
    // The dataset is small enough that the copy costs nothing worth measuring.

    private static func backUpStoreIfPresent() {
        let fileManager = FileManager.default
        guard let directory = fileManager
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first
        else { return }

        let store = directory.appendingPathComponent("TProgress.sqlite")
        guard fileManager.fileExists(atPath: store.path) else { return }

        // The write-ahead log holds committed pages that have not been folded
        // back into the main file yet. A backup that skips it can lose the most
        // recent entries, which are the ones worth the trouble.
        let stamp = ISO8601DateFormatter()
            .string(from: Date())
            .replacingOccurrences(of: ":", with: "-")

        for suffix in ["", "-wal"] {
            let source = directory.appendingPathComponent("TProgress.sqlite\(suffix)")
            guard fileManager.fileExists(atPath: source.path) else { continue }
            let target = directory.appendingPathComponent("TProgress-\(stamp).sqlite\(suffix)")
            try? fileManager.copyItem(at: source, to: target)
        }

        // ISO-8601 stamps sort lexically, so the newest are simply the last
        // names. Three deep is enough to survive a bad upgrade and the relaunch
        // that follows it.
        let contents = (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )) ?? []

        let backups = contents
            .filter { $0.lastPathComponent.hasPrefix("TProgress-") && $0.pathExtension == "sqlite" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }

        for old in backups.dropFirst(3) {
            try? fileManager.removeItem(at: old)
            let log = old.deletingPathExtension().appendingPathExtension("sqlite-wal")
            try? fileManager.removeItem(at: log)
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
