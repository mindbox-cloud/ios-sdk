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
    
    var persistentContainer: NSPersistentContainer {
        container.databaseRepository.persistentContainer
    }
    
    var container: TestDependencyProvider!
    
    override func setUp() {
        super.setUp()
        container = try! TestDependencyProvider()
    }
    
    override func tearDown() {
        
        container = nil
        super.tearDown()
    }
    
    func testDestroyDatabase() {
        XCTAssertNotNil(persistentContainer.persistentStoreCoordinator.persistentStore(for: container.databaseLoader.persistentStoreURL!))
        try! container.databaseLoader.destroy()
        XCTAssertNil(persistentContainer.persistentStoreCoordinator.persistentStore(for: container.databaseLoader.persistentStoreURL!))
    }
}
