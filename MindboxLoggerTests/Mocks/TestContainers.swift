//
//  TestContainers.swift
//  MindboxTests
//
//  Created by Sergei Semko on 9/11/25.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import Foundation
import CoreData
@testable import MindboxLogger

final class AlwaysFailLoader: LoggerDatabaseLoading {
    func loadContainer() throws -> (container: MBPersistentContainer, context: NSManagedObjectContext) {
        struct E: Error {}
        throw E()
    }
    func destroyIfExists() throws {}
}

final class EphemeralSQLiteLoader: LoggerDatabaseLoading {
    private let url: URL
    private let modelName: String

    init(modelName: String = "CDLogMessage") {
        self.modelName = modelName
        self.url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("MB-Tests-\(UUID().uuidString).sqlite")
    }

    func loadContainer() throws -> (container: MBPersistentContainer, context: NSManagedObjectContext) {
        MBPersistentContainer.applicationGroupIdentifier = nil

        let ownerBundle = Bundle(for: MBLoggerCoreDataManager.self)
        guard
            let bundleURL = ownerBundle.url(forResource: "MindboxLogger", withExtension: "bundle"),
            let bundle = Bundle(url: bundleURL),
            let modelURL = bundle.url(forResource: modelName, withExtension: "momd"),
            let mom = NSManagedObjectModel(contentsOf: modelURL)
        else { throw LoggerDatabaseLoaderError.modelNotFound(modelName: modelName) }

        let container = MBPersistentContainer(name: modelName, managedObjectModel: mom)
        let d = NSPersistentStoreDescription(url: url)
        d.type = NSSQLiteStoreType
        d.shouldAddStoreAsynchronously = false
        d.setOption(FileProtectionType.none as NSObject, forKey: NSPersistentStoreFileProtectionKey)
        container.persistentStoreDescriptions = [d]

        var err: Error?
        container.loadPersistentStores { _, e in err = e }
        if let err { throw err }

        let ctx = container.newBackgroundContext()
        ctx.automaticallyMergesChangesFromParent = true
        ctx.mergePolicy = NSMergePolicy(merge: .mergeByPropertyStoreTrumpMergePolicyType)
        return (container, ctx)
    }

    func destroyIfExists() throws {}
}
