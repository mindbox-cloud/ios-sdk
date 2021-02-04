//
//  MBDatabaseRepository.swift
//  MindBox
//
//  Created by Maksim Kazachkov on 04.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
import CoreData

class MBDatabaseRepository {
    
    private let persistentContainer: NSPersistentContainer
    private let context: NSManagedObjectContext
    
    init(persistentStoreDescriptions: [NSPersistentStoreDescription]? = nil) throws {
        let bundle = Bundle(for: Self.self)
        let momdName = "MBDatabase"
        guard let modelURL = bundle.url(forResource: momdName, withExtension: "momd") else {
            throw MBDatabaseError.unableCreateDatabaseModel
        }
        guard let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL) else {
            throw MBDatabaseError.unableCreateManagedObjectModel(with: modelURL)
        }
        let persistentContainer = NSPersistentContainer(name: momdName, managedObjectModel: managedObjectModel)
        // Set descriptions if needed
        if let persistentStoreDescriptions = persistentStoreDescriptions {
            persistentContainer.persistentStoreDescriptions = persistentStoreDescriptions
        }
        var loadPersistentStoresError: Error?
        persistentContainer.loadPersistentStores { (persistentStoreDescription, error) in
            if let persistentStoreURL = persistentStoreDescription.url {
                Log("Persistent store url: \(persistentStoreURL.description)")
                    .inChanel(.database).withType(.info).make()
            } else {
                Log("Unable find persistentStoreURL")
                    .inChanel(.database).withType(.error).make()
            }
            
            loadPersistentStoresError = error
        }
        if let error = loadPersistentStoresError {
            throw MBDatabaseError.unableToLoadPeristentStore(localizedDescription: error.localizedDescription)
        }
        self.persistentContainer = persistentContainer
        self.context = persistentContainer.newBackgroundContext()
        self.context.automaticallyMergesChangesFromParent = true
        self.context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyStoreTrumpMergePolicyType)
    }
    
}
