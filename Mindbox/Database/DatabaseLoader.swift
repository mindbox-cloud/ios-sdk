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

class DataBaseLoader {
    
    private let persistentStoreDescriptions: [NSPersistentStoreDescription]?
    private let persistentContainer: NSPersistentContainer
    var persistentStoreDescription: NSPersistentStoreDescription?
    
    var loadPersistentStoresError: Error?
    var persistentStoreURL: URL?
    
    init(persistentStoreDescriptions: [NSPersistentStoreDescription]? = nil, applicationGroupIdentifier: String? = nil) throws {
        MBPersistentContainer.applicationGroupIdentifier = applicationGroupIdentifier
        let momdName = Constants.Database.mombName
        var modelURL: URL?

        #if SWIFT_PACKAGE
        if let modelURLSwift = Bundle.module.url(forResource: momdName, withExtension: "momd") {
            modelURL = modelURLSwift
        }
        #else

        if let podBundle = Bundle(for: DataBaseLoader.self).url(forResource: "Mindbox", withExtension: "bundle"),
           let modelURLPod = Bundle(url: podBundle)?.url(forResource: momdName, withExtension: "momd") {
            modelURL = modelURLPod
        } else if let modelURLAdditional = Bundle(for: DataBaseLoader.self).url(forResource: momdName, withExtension: "momd") {
            modelURL = modelURLAdditional
        }

        #endif
        
        guard let modelURL = modelURL else {
            Logger.common(message: MBDatabaseError.unableCreateDatabaseModel.errorDescription, level: .error, category: .database)
            throw MBDatabaseError.unableCreateDatabaseModel
        }

        guard let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL) else {
            Logger.common(message: MBDatabaseError.unableCreateManagedObjectModel(with: modelURL).errorDescription, level: .error, category: .database)
            throw MBDatabaseError.unableCreateManagedObjectModel(with: modelURL)
        }
        self.persistentContainer = MBPersistentContainer(
            name: momdName,
            managedObjectModel: managedObjectModel
        )
        
        self.persistentStoreDescriptions = persistentStoreDescriptions
        if let persistentStoreDescriptions = persistentStoreDescriptions {
            persistentContainer.persistentStoreDescriptions = persistentStoreDescriptions
        }
        persistentContainer.persistentStoreDescriptions.forEach {
            $0.shouldMigrateStoreAutomatically = true
            $0.shouldInferMappingModelAutomatically = true
        }
    }
    
    func loadPersistentContainer() throws -> NSPersistentContainer {
        do {
            return try loadPersistentStores()
        } catch {
            do {
                try destroy()
                return try loadPersistentStores()
            }
        }
    }
    
    private func loadPersistentStores() throws -> NSPersistentContainer {
        persistentContainer.loadPersistentStores { [weak self] (persistentStoreDescription, error) in
            if let url = persistentStoreDescription.url {
                Logger.common(message: "Persistent store url: \(url.description)", level: .info, category: .database)
            } else {
                Logger.common(message: "Unable to find persistentStoreURL", level: .error, category: .database)
            }
            self?.persistentStoreURL = persistentStoreDescription.url
            self?.loadPersistentStoresError = error
            self?.persistentStoreDescription = persistentStoreDescription
        }
        if let error = loadPersistentStoresError {
            Logger.common(message: "Load persistent stores error: \(error) ", level: .error, category: .database)
            throw error
        }
        return persistentContainer
    }
    
    func destroy() throws {
        guard let persistentStoreURL = persistentStoreURL else {
            Logger.common(message: MBDatabaseError.persistentStoreURLNotFound.errorDescription, level: .error, category: .database)
            throw MBDatabaseError.persistentStoreURLNotFound
        }

        Logger.common(message: "Removing database at url: \(persistentStoreURL.absoluteString)", level: .info, category: .database)
        
        guard FileManager.default.fileExists(atPath: persistentStoreURL.path) else {
            Logger.common(message: MBDatabaseError.persistentStoreNotExistsAtURL(path: persistentStoreURL.path).errorDescription, level: .error, category: .database)
            throw MBDatabaseError.persistentStoreNotExistsAtURL(path: persistentStoreURL.path)
        }
        do {
            try self.persistentContainer.persistentStoreCoordinator.destroyPersistentStore(at: persistentStoreURL, ofType: "sqlite", options: nil)
            Logger.common(message: "Database has been removed", level: .info, category: .database)
        } catch {
            Logger.common(message: "Removed database failed with error: \(error.localizedDescription)", level: .error, category: .database)
            throw error
        }
    }
    
}
