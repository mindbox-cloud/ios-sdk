//
//  DatabaseMetadataMigration.swift
//  Mindbox
//
//  Created by Sergei Semko on 10/1/25.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import Foundation
import CoreData
import MindboxLogger // MBPersistentContainer

final class DatabaseMetadataMigration: MigrationProtocol {
    
    private typealias MDKey = Constants.StoreMetadataKey

    private var persistenceStorage: PersistenceStorage = DI.injectOrFail(PersistenceStorage.self)
    
    private lazy var candidateStoreURLs: [URL] = {
        let fileName = "\(Constants.Database.mombName).sqlite"
        var urls: [URL] = []
        // 1) App Group base directory provided by our container
        urls.append(MBPersistentContainer.defaultDirectoryURL().appendingPathComponent(fileName))
        // 2) Default Application Support directory used by NSPersistentContainer
        urls.append(NSPersistentContainer.defaultDirectoryURL().appendingPathComponent(fileName))
        // Deduplicate and standardize
        return Array(Set(urls.map { $0.standardizedFileURL }))
    }()
    
    private var existingStoreURLs: [URL] {
        let fm = FileManager.default
        return candidateStoreURLs.filter { fm.fileExists(atPath: $0.path) }
    }

    var description: String {
        "Migration metadata from MBDatabaseRepository CoreData to MBPersistenceStorage UserDefaults. Starting with SDK 2.14.2."
    }

    var isNeeded: Bool {
        let hasMDInfoUpdate = read(Int.self, .infoUpdate) != nil
        let hasMDInstanceId = read(String.self, .instanceId) != nil

        let needsCopyInfoUpdate = persistenceStorage.applicationInfoUpdateVersion == nil && hasMDInfoUpdate
        let needsCopyInstanceId = persistenceStorage.applicationInstanceId == nil && hasMDInstanceId

        let needsCleanup = (persistenceStorage.applicationInfoUpdateVersion != nil && hasMDInfoUpdate)
                        || (persistenceStorage.applicationInstanceId != nil && hasMDInstanceId)

        return needsCopyInfoUpdate || needsCopyInstanceId || needsCleanup
    }

    var version: Int {
        3
    }

    func run() throws {
        let infoUpdateVersion: Int? = read(Int.self, .infoUpdate)
        let instanceId: String?     = read(String.self, .instanceId)
        
        if persistenceStorage.applicationInfoUpdateVersion == nil {
            persistenceStorage.applicationInfoUpdateVersion = infoUpdateVersion
        }
        if persistenceStorage.applicationInstanceId == nil {
            persistenceStorage.applicationInstanceId = instanceId
        }
        
        clear(.infoUpdate)
        clear(.instanceId)
    }
    
    // MARK: - I/O helpers (disk-only, no live PSC dependency)

    /// Typed metadata read. Iterates existing candidate files and returns the first typed match.
    private func read<T>(_ type: T.Type, _ key: MDKey) -> T? {
        for url in existingStoreURLs {
            do {
                let md = try NSPersistentStoreCoordinator.metadataForPersistentStore(
                    ofType: NSSQLiteStoreType,
                    at: url,
                    options: [NSReadOnlyPersistentStoreOption: true]
                )
                if let value = md[key.rawValue] as? T { return value }
            } catch {
                // Ignore and try the next candidate.
            }
        }
        return nil
    }

    /// Removes the metadata key from *all* existing candidate store files.
    /// Uses class-level Core Data APIs to avoid loading the store into memory.
    private func clear(_ key: MDKey) {
        for url in existingStoreURLs {
            do {
                var md = try NSPersistentStoreCoordinator.metadataForPersistentStore(
                    ofType: NSSQLiteStoreType,
                    at: url,
                    options: [NSReadOnlyPersistentStoreOption: true]
                )
                if md.removeValue(forKey: key.rawValue) != nil {
                    try NSPersistentStoreCoordinator.setMetadata(
                        md,
                        forPersistentStoreOfType: NSSQLiteStoreType,
                        at: url,
                        options: nil
                    )
                }
            } catch {
                // Best effort: do not block SDK startup if cleanup fails.
            }
        }
    }
}
