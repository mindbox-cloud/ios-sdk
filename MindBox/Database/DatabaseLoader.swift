//
//  DatabaseLoader.swift
//  MindBox
//
//  Created by Maksim Kazachkov on 01.03.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
import CoreData

class MBPersistentContainer: NSPersistentContainer {
    
    static var applicationGroupIdentifier: String? = nil
        
    override class func defaultDirectoryURL() -> URL {
        guard let applicationGroupIdentifier = applicationGroupIdentifier else {
            return super.defaultDirectoryURL()
        }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: applicationGroupIdentifier) ?? super.defaultDirectoryURL()
    }
    
}

class DataBaseLoader {
    
    private let persistentStoreDescriptions: [NSPersistentStoreDescription]?
    private let persistentContainer: NSPersistentContainer
    
    var loadPersistentStoresError: Error?
    var persistentStoreURL: URL?
    
    init(persistentStoreDescriptions: [NSPersistentStoreDescription]? = nil, appGroup: String? = nil) throws {
        MBPersistentContainer.applicationGroupIdentifier = appGroup
        let bundle = Bundle(for: DataBaseLoader.self)
        let momdName = "MBDatabase"
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
                    .inChanel(.database).withType(.info).make()
            } else {
                Log("Unable to find persistentStoreURL")
                    .inChanel(.database).withType(.error).make()
            }
            self?.persistentStoreURL = persistentStoreDescription.url
            self?.loadPersistentStoresError = error
        }
        if let error = loadPersistentStoresError {
            throw error
        }
        return persistentContainer
    }
    
    private func destroy() throws {
        guard let persistentStoreURL = persistentStoreURL else {
            throw MBDatabaseError.persistentStoreURLNotFound
        }
        Log("Removing database at url: \(persistentStoreURL.absoluteString)")
            .inChanel(.database).withType(.info).make()
        guard FileManager.default.fileExists(atPath: persistentStoreURL.path) else {
            throw MBDatabaseError.persistentStoreNotExistsAtURL(path: persistentStoreURL.path)
        }
        Log("Unable to find database at path: \(persistentStoreURL.path)")
            .inChanel(.database).withType(.error).make()
        do {
            try FileManager.default.removeItem(at: persistentStoreURL)
            Log("Removed database")
                .inChanel(.database).withType(.info).make()
        } catch {
            Log("Removed database failed with error: \(error.localizedDescription)")
                .inChanel(.database).withType(.error).make()
            throw error
        }
    }
    
}
