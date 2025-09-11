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

private func makeTestModel() -> NSManagedObjectModel {
    let bundle   = Bundle(for: MBLoggerCoreDataManager.self)
    let url      = bundle.url(forResource: "CDLogMessage", withExtension: "momd")!
    return NSManagedObjectModel(contentsOf: url)!
}

/// Container: first load fails, second load succeeds (adds In-Memory store).
final class TestContainerFailOnce: MBPersistentContainer, @unchecked Sendable {
    private(set) var loadCalls = 0
    private(set) var capturedDescription: NSPersistentStoreDescription?

    init() {
        super.init(name: "CDLogMessage", managedObjectModel: makeTestModel())
    }

    override func loadPersistentStores(completionHandler block: @escaping (NSPersistentStoreDescription, Error?) -> Void) {
        let desc = persistentStoreDescriptions.first!
        capturedDescription = desc
        loadCalls += 1

        if loadCalls == 1 {
            block(desc, NSError(domain: "test.fail.once", code: 1))
        } else {
            do {
                try persistentStoreCoordinator.addPersistentStore(ofType: NSInMemoryStoreType,
                                                                  configurationName: nil,
                                                                  at: nil,
                                                                  options: nil)
                block(desc, nil)
            } catch {
                block(desc, error)
            }
        }
    }
}

/// Container: always fails.
final class TestContainerAlwaysFail: MBPersistentContainer, @unchecked Sendable {
    private(set) var loadCalls = 0
    private(set) var capturedDescription: NSPersistentStoreDescription?

    init() {
        super.init(name: "CDLogMessage", managedObjectModel: makeTestModel())
    }

    override func loadPersistentStores(completionHandler block: @escaping (NSPersistentStoreDescription, Error?) -> Void) {
        let desc = persistentStoreDescriptions.first!
        capturedDescription = desc
        loadCalls += 1
        block(desc, NSError(domain: "test.always.fail", code: 2))
    }
}
