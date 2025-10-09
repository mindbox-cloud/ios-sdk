//
//  DatabaseLoader.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 01.03.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation
import CoreData
import MindboxLogger

class DatabaseLoader: DatabaseLoaderProtocol {
    
    /// Keys from the Core Data store metadata that must survive store repair or a fallback to an in-memory store.
    ///
    /// These keys are:
    /// - read from the existing on-disk SQLite store in **read-only** mode by `salvageMetadataFromOnDiskStore()`
    /// - merged into the newly loaded (on-disk or in-memory) store by `applyMetadata(_:to:)`
    ///
    /// Keep this list minimal to avoid dragging unrelated metadata across store lifecycles.
    static var metadataKeysToPreserve: [String] { Constants.StoreMetadataKey.preserved }
    
    private let diskSpaceRepairThreshold: Int64 = 300 * 1024 * 1024 // 300 MB
    
    var freeSize: Int64 {
        let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
        return (attrs?[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
    }
    
    private let persistentContainer: NSPersistentContainer
    
    private var storeURL: URL? {
        persistentContainer.persistentStoreCoordinator.persistentStores.first?.url
    }
    
    init(persistentStoreDescriptions: [NSPersistentStoreDescription]? = nil, applicationGroupIdentifier: String? = nil) throws {
        MBPersistentContainer.applicationGroupIdentifier = applicationGroupIdentifier
        
        let momdName = Constants.Database.mombName
        let modelURL: URL? = {
        #if SWIFT_PACKAGE
            return Bundle.module.url(forResource: momdName, withExtension: "momd")
        #else
            if let pod = Bundle(for: DatabaseLoader.self).url(forResource: "Mindbox", withExtension: "bundle"),
               let url = Bundle(url: pod)?.url(forResource: momdName, withExtension: "momd") {
                return url
            }
            return Bundle(for: DatabaseLoader.self).url(forResource: momdName, withExtension: "momd")
        #endif
        }()
        
        guard let modelURL, let model = NSManagedObjectModel(contentsOf: modelURL) else {
            Logger.common(message: MBDatabaseError.unableCreateDatabaseModel.errorDescription, level: .error, category: .database)
            throw MBDatabaseError.unableCreateDatabaseModel
        }
        
        let container = MBPersistentContainer(name: momdName, managedObjectModel: model)
        if let descs = persistentStoreDescriptions {
            container.persistentStoreDescriptions = descs
        }
        
        Self.applyStandardOptions(to: container.persistentStoreDescriptions)
        self.persistentContainer = container
    }
    
    private static func applyStandardOptions(to descriptions: [NSPersistentStoreDescription]) {
        descriptions.forEach {
            $0.shouldAddStoreAsynchronously = false
            $0.setOption(FileProtectionType.none as NSObject, forKey: NSPersistentStoreFileProtectionKey)
            $0.shouldMigrateStoreAutomatically = true
            $0.shouldInferMappingModelAutomatically = true
        }
    }

    func loadPersistentStores() throws -> NSPersistentContainer {
        var capturedError: Error?
        
        persistentContainer.loadPersistentStores { persistentStoreDescription, error in
            if let url = persistentStoreDescription.url {
                Logger.common(message: "[DBLoader] Store URL: \(url.path)", level: .info, category: .database)
            } else {
                Logger.common(message: "[DBLoader] Store URL is nil (in-memory or misconfigured)", level: .info, category: .database)
            }
            capturedError = error
        }
        if let capturedError {
            Logger.common(message: "[DBLoader] Failed to load persistent stores: \(capturedError)", level: .error, category: .database)
            throw capturedError
        }
        return persistentContainer
    }
    
    /// Attempts to **salvage** selected metadata keys directly from the **on-disk** SQLite store,
    /// without opening/attaching the store to a context.
    ///
    /// This is used when:
    /// - loading the persistent store fails (corruption, schema mismatch, etc.), or
    /// - before we intentionally destroy the store as part of a repair attempt.
    ///
    /// The read is performed via `NSPersistentStoreCoordinator.metadataForPersistentStore`
    /// with `NSReadOnlyPersistentStoreOption` to avoid modifying or locking the store.
    ///
    /// - Returns: A dictionary containing only the keys listed in `metadataKeysToPreserve`,
    ///            or `nil` if nothing was read or an error occurred.
    /// - Note: The returned values are raw metadata items (`[String: Any]`), ready to be
    ///         merged into a new store by `applyMetadata(_:to:)`.
    func salvageMetadataFromOnDiskStore() -> [String: Any]? {
        guard let url = persistentContainer.persistentStoreDescriptions.first?.url else { return nil }
        let opts: [AnyHashable: Any] = [NSReadOnlyPersistentStoreOption: true]
        do {
            let raw = try NSPersistentStoreCoordinator.metadataForPersistentStore(
                ofType: NSSQLiteStoreType,
                at: url,
                options: opts
            )
            let filtered = raw.filter { Self.metadataKeysToPreserve.contains($0.key) }
            return filtered.isEmpty ? nil : filtered
        } catch {
            Logger.common(message: "[DBLoader] Can't read metadata for salvage (read-only): \(error)",
                          level: .error, category: .database)
            return nil
        }
    }

    /// Merges previously preserved metadata into the specified container's first persistent store.
    ///
    /// Call this **after** you successfully created a new on-disk store or an in-memory fallback.
    /// Only the provided keys are merged; existing unrelated metadata entries are left intact.
    ///
    /// - Parameters:
    ///   - preserved: The dictionary returned by `salvageMetadataFromOnDiskStore()`.
    ///   - container: The `NSPersistentContainer` that has already loaded its stores.
    /// - Important: This method is a no-op if there is no store or `preserved` is empty.
    /// - Effects: Persists the merged metadata to the target store via
    ///            `NSPersistentStoreCoordinator.setMetadata(_:for:)`.
    func applyMetadata(_ preserved: [String: Any], to container: NSPersistentContainer) {
        let psc = container.persistentStoreCoordinator
        guard let store = psc.persistentStores.first, !preserved.isEmpty else { return }
        var meta = psc.metadata(for: store)
        preserved.forEach { meta[$0.key] = $0.value }
        psc.setMetadata(meta, for: store)
        Logger.common(message: "[DBLoader] Preserved metadata reapplied: \(Array(preserved.keys))",
                      level: .info, category: .database)
    }
    
    // MARK: - DataBaseLoading
    
    func makeInMemoryContainer() throws -> NSPersistentContainer {
        let model = persistentContainer.managedObjectModel
        let container = MBPersistentContainer(name: persistentContainer.name, managedObjectModel: model)

        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        Self.applyStandardOptions(to: [description])
        container.persistentStoreDescriptions = [description]

        var capturedError: Error?
        container.loadPersistentStores { _, error in
            capturedError = error
        }
        if let capturedError { throw capturedError }
        return container
    }
    
    func loadPersistentContainer() throws -> NSPersistentContainer {
        do {
            return try loadPersistentStores()
        } catch {
            Logger.common(message: "[DBLoader] On-disk load failed: \(error)",
                                      level: .error, category: .database)
        }
        
        let preserved = salvageMetadataFromOnDiskStore()

        let freeSize = freeSize
        if freeSize < diskSpaceRepairThreshold {
            Logger.common(message: "[DBLoader] Low disk space (\(freeSize)<\(diskSpaceRepairThreshold)); using InMemory without touching store", level: .error, category: .database)
            let mem = try makeInMemoryContainer()
            if let preserved { applyMetadata(preserved, to: mem) }
            return mem
        }
        
        do {
            try destroy()
            let retried = try loadPersistentStores()
            if let preserved { applyMetadata(preserved, to: retried) }
            Logger.common(message: "[DBLoader] On-disk retry succeeded after destroy", level: .info, category: .database)
            return retried
        } catch {
            Logger.common(message: "[DBLoader] Repair attempt failed: \(error). Falling back to InMemory.", level: .error, category: .database)
            return try makeInMemoryContainer()
        }
    }
    
    func destroy() throws {
        let persistentStoreURL = storeURL ?? persistentContainer.persistentStoreDescriptions.first?.url
        guard let persistentStoreURL else {
            Logger.common(message: MBDatabaseError.persistentStoreURLNotFound.errorDescription, level: .error, category: .database)
            throw MBDatabaseError.persistentStoreURLNotFound
        }

        let psc = persistentContainer.persistentStoreCoordinator
        Logger.common(message: "[DBLoader] Removing database at path: \(persistentStoreURL.path)",
                          level: .info, category: .database)

        do {
            if #available(iOS 15.0, *) {
                try psc.destroyPersistentStore(at: persistentStoreURL, type: .sqlite)
            } else {
                try psc.destroyPersistentStore(at: persistentStoreURL, ofType: NSSQLiteStoreType)
            }
            
            Logger.common(message: "[DBLoader] Database removed at \(persistentStoreURL.path)", level: .info, category: .database)
        } catch {
            Logger.common(message: "[DBLoader] Failed to remove database: \(error.localizedDescription)", level: .error, category: .database)
            throw error
        }
    }
}
