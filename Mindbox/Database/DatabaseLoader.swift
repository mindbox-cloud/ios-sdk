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

final class DatabaseLoader {
    
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

    private func loadPersistentStores() throws -> NSPersistentContainer {
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
    
    private static func applyStandardOptions(to descriptions: [NSPersistentStoreDescription]) {
        descriptions.forEach {
            $0.shouldAddStoreAsynchronously = false
            $0.setOption(FileProtectionType.none as NSObject, forKey: NSPersistentStoreFileProtectionKey)
            $0.shouldMigrateStoreAutomatically = true
            $0.shouldInferMappingModelAutomatically = true
        }
    }
}

// MARK: - DataBaseLoading

extension DatabaseLoader: DatabaseLoading {
    
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
        
        do {
            try destroy()
            let retried = try loadPersistentStores()
            Logger.common(message: "[DBLoader] On-disk retry succeeded after destroy", level: .info, category: .database)
            return retried
        } catch {
            Logger.common(message: "[DBLoader] Retry after destroy failed: \(error)", level: .error, category: .database)
        }
    
        Logger.common(message: "[DBLoader] Falling back to InMemory store", level: .error, category: .database)
        return try makeInMemoryContainer()
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

final class StubLoader: DatabaseLoading {
    func loadPersistentContainer() throws -> NSPersistentContainer { throw MBDatabaseError.unableCreateDatabaseModel }
    func makeInMemoryContainer() throws -> NSPersistentContainer { throw MBDatabaseError.unableCreateDatabaseModel }
    func destroy() throws {}
}
