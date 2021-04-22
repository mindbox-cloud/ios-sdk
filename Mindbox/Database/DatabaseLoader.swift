//
//  DatabaseLoader.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 01.03.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
import CoreData

class DataBaseLoader {
    
    private let persistentStoreDescriptions: [NSPersistentStoreDescription]?
    private let persistentContainer: NSPersistentContainer
    var persistentStoreDescription: NSPersistentStoreDescription?
    
    var loadPersistentStoresError: Error?
    var persistentStoreURL: URL?
    
    init(persistentStoreDescriptions: [NSPersistentStoreDescription]? = nil, applicationGroupIdentifier: String? = nil) throws {
        MBPersistentContainer.applicationGroupIdentifier = applicationGroupIdentifier
        let bundle = Bundle(for: DataBaseLoader.self)
        let momdName = Constants.Database.mombName
        guard let modelURL = bundle.url(forResource: momdName, withExtension: "momd") else {
            throw MBDatabaseError.unableCreateDatabaseModel
        }
        guard let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL) else {
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
                Log("Persistent store url: \(url.description)")
                    .category(.database).level(.info).make()
            } else {
                Log("Unable to find persistentStoreURL")
                    .category(.database).level(.error).make()
            }
            self?.persistentStoreURL = persistentStoreDescription.url
            self?.loadPersistentStoresError = error
            self?.persistentStoreDescription = persistentStoreDescription
        }
        if let error = loadPersistentStoresError {
            throw error
        }
        return persistentContainer
    }
    
    func destroy() throws {
        guard let persistentStoreURL = persistentStoreURL else {
            throw MBDatabaseError.persistentStoreURLNotFound
        }
        Log("Removing database at url: \(persistentStoreURL.absoluteString)")
            .category(.database).level(.info).make()
        guard FileManager.default.fileExists(atPath: persistentStoreURL.path) else {
            Log("Unable to find database at path: \(persistentStoreURL.path)")
                .category(.database).level(.error).make()
            throw MBDatabaseError.persistentStoreNotExistsAtURL(path: persistentStoreURL.path)
        }
        do {
            try self.persistentContainer.persistentStoreCoordinator.destroyPersistentStore(at: persistentStoreURL, ofType: "sqlite", options: nil)
            Log("Database has been removed")
                .category(.database).level(.info).make()
        } catch {
            Log("Removed database failed with error: \(error.localizedDescription)")
                .category(.database).level(.error).make()
            throw error
        }
    }
    
}
