//
//  DatabaseLoaderTest.swift
//  MindboxTests
//
//  Created by Maksim Kazachkov on 07.04.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import XCTest
import CoreData
@testable import Mindbox

class DatabaseLoaderTest: XCTestCase {
    
    var persistentContainer: NSPersistentContainer!
    var databaseLoader: DataBaseLoader!
    
    override func setUp() {
        super.setUp()
        databaseLoader = DI.injectOrFail(DataBaseLoader.self)
        persistentContainer = DI.injectOrFail(MBDatabaseRepository.self).persistentContainer
    }
    
    override func tearDown() {
        databaseLoader = nil
        persistentContainer = nil
        super.tearDown()
    }
    
    func testDestroyDatabase() {
        let persistentStoreURL = databaseLoader.persistentStoreURL!
        XCTAssertNotNil(persistentContainer.persistentStoreCoordinator.persistentStore(for: persistentStoreURL))
        try! databaseLoader.destroy()
        XCTAssertNil(persistentContainer.persistentStoreCoordinator.persistentStore(for: persistentStoreURL))
    }
}
