//
//  LoggerDatabaseLoader.swift
//  MindboxLogger
//
//  Created by Sergei Semko on 9/11/25.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import Foundation
import CoreData

protocol LoggerDatabaseLoading {
    func loadContainer() throws -> (container: MBPersistentContainer, context: NSManagedObjectContext)
    
    func destroyIfExists() throws
}

struct LoggerDatabaseLoaderConfig {
    let modelName: String
    let applicationGroupId: String?
    let storeURL: URL?
    let descriptions: [NSPersistentStoreDescription]?
}

enum LoggerDatabaseLoaderError: LocalizedError {
    case modelNotFound(modelName: String)

    var errorDescription: String? {
        switch self {
        case .modelNotFound(let modelName):
            return "Core Data model '\(modelName).momd' not found in any known bundle."
        }
    }
}

final class LoggerDatabaseLoader: LoggerDatabaseLoading {
    private let configuration: LoggerDatabaseLoaderConfig

    init(_ configuration: LoggerDatabaseLoaderConfig) {
        self.configuration = configuration
    }
    
    // MARK: - Public

    func loadContainer() throws -> (container: MBPersistentContainer, context: NSManagedObjectContext) {
        MBPersistentContainer.applicationGroupIdentifier = configuration.applicationGroupId

        let managedObjectModel = try resolveModel()

        let container = MBPersistentContainer(name: configuration.modelName, managedObjectModel: managedObjectModel)
        let storeURL = try resolveStoreURL()

        if let explicitDescriptions = configuration.descriptions, !explicitDescriptions.isEmpty {
            container.persistentStoreDescriptions = explicitDescriptions
        } else {
            container.persistentStoreDescriptions = [defaultDescription(forStoreURL: storeURL)]
        }

        do {
            try loadStores(into: container)
        } catch {
            try destroyStore(at: storeURL, using: container)
            try loadStores(into: container)
        }

        let backgroundContext = container.newBackgroundContext()
        backgroundContext.automaticallyMergesChangesFromParent = true
        backgroundContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyStoreTrumpMergePolicyType)

        return (container, backgroundContext)
    }
    
    func destroyIfExists() throws {
        let storeURL = try resolveStoreURL()
        let fm = FileManager.default

        let walURL = URL(fileURLWithPath: storeURL.path + "-wal")
        let shmURL = URL(fileURLWithPath: storeURL.path + "-shm")

        if fm.fileExists(atPath: storeURL.path) {
            let psc = NSPersistentStoreCoordinator(managedObjectModel: NSManagedObjectModel())
            if #available(iOS 15.0, *) {
                try? psc.destroyPersistentStore(at: storeURL, type: .sqlite,
                                                options: [NSPersistentStoreForceDestroyOption: true])
            } else {
                try? psc.destroyPersistentStore(at: storeURL, ofType: NSSQLiteStoreType, options: nil)
            }

            if fm.fileExists(atPath: storeURL.path) {
                try? fm.removeItem(at: storeURL)
            }
        }

        try? fm.removeItem(at: walURL)
        try? fm.removeItem(at: shmURL)
    }

    // MARK: - Model resolution
    
    private func resolveModel() throws -> NSManagedObjectModel {
        #if SWIFT_PACKAGE
        if let url = Bundle.module.url(forResource: configuration.modelName, withExtension: "momd"),
           let model = NSManagedObjectModel(contentsOf: url) {
            return model
        }
        #endif

        let ownerBundle = Bundle(for: MBLoggerCoreDataManager.self)
        if let directURL = ownerBundle.url(forResource: configuration.modelName, withExtension: "momd"),
           let model = NSManagedObjectModel(contentsOf: directURL) {
            return model
        }

        if let nestedURL = ownerBundle.url(forResource: "MindboxLogger", withExtension: "bundle"),
           let nestedBundle = Bundle(url: nestedURL),
           let modelURL = nestedBundle.url(forResource: configuration.modelName, withExtension: "momd"),
           let model = NSManagedObjectModel(contentsOf: modelURL) {
            return model
        }

        throw LoggerDatabaseLoaderError.modelNotFound(modelName: configuration.modelName)
    }

    // MARK: - Store helpers

    private func defaultDescription(forStoreURL storeURL: URL) -> NSPersistentStoreDescription {
        let storeDescription = NSPersistentStoreDescription(url: storeURL)
        storeDescription.setOption(FileProtectionType.none as NSObject, forKey: NSPersistentStoreFileProtectionKey)
        storeDescription.shouldAddStoreAsynchronously = false
        storeDescription.shouldMigrateStoreAutomatically = true
        storeDescription.shouldInferMappingModelAutomatically = true
        return storeDescription
    }

    private func loadStores(into container: NSPersistentContainer) throws {
        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let loadError {
            throw loadError
        }
    }

    private func destroyStore(at storeURL: URL, using container: NSPersistentContainer) throws {
        if #available(iOS 15.0, *) {
            try container.persistentStoreCoordinator.destroyPersistentStore(at: storeURL, type: .sqlite)
        } else {
            try container.persistentStoreCoordinator.destroyPersistentStore(at: storeURL, ofType: NSSQLiteStoreType)
        }
    }

    private func resolveStoreURL() throws -> URL {
        if let firstDescription = configuration.descriptions?.first, let explicitURL = firstDescription.url {
            return explicitURL
        }
        if let explicitURL = configuration.storeURL {
            return explicitURL
        }
        if let applicationGroupId = configuration.applicationGroupId {
            return try FileManager.storeURL(for: applicationGroupId, databaseName: configuration.modelName)
        }
        let cachesDirectory = try FileManager.default.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return cachesDirectory.appendingPathComponent("\(configuration.modelName).sqlite")
    }
}
