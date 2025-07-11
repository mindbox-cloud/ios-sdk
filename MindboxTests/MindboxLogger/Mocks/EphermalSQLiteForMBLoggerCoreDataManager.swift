//
//  EphermalSQLiteForMBLoggerCoreDataManager.swift
//  MindboxTests
//
//  Created by Sergei Semko on 7/11/25.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import Foundation
import CoreData
@testable import MindboxLogger

#if DEBUG
extension MBLoggerCoreDataManager {

    private static let testContainer: MBPersistentContainer = {
        let bundle   = Bundle(for: MBLoggerCoreDataManager.self)
        let modelURL = bundle.url(forResource: "CDLogMessage", withExtension: "momd")!
        let model    = NSManagedObjectModel(contentsOf: modelURL)!

        let container = MBPersistentContainer(name: "CDLogMessage",
                                              managedObjectModel: model)

        let url  = URL(fileURLWithPath: NSTemporaryDirectory())
                     .appendingPathComponent("MindboxLogger-tests.sqlite")

        let desc = NSPersistentStoreDescription(url: url)
        desc.type                    = NSSQLiteStoreType
        desc.shouldAddStoreAsynchronously = false

        container.persistentStoreDescriptions = [desc]
        container.loadPersistentStores { _, err in
            precondition(err == nil, "‼️ Unable to load test store: \(err!)")
        }
        return container
    }()

    static func makeEphemeral() -> MBLoggerCoreDataManager {
        let manager = MBLoggerCoreDataManager(debug: true)

        manager.debugPersistentContainer = Self.testContainer
        manager.debugContext             = Self.testContainer.newBackgroundContext()
        manager.debugContext.mergePolicy = NSMergePolicy(
            merge: .mergeByPropertyStoreTrumpMergePolicyType
        )
        return manager
    }
}
#endif
