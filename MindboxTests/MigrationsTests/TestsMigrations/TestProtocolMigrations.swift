//
//  TestProtocolMigrations.swift
//  MindboxTests
//
//  Created by Sergei Semko on 8/6/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
@testable import Mindbox

final class TestProtocolMigration_1: MigrationProtocol {
    var description: String {
        "TestProtocolMigration number 1 with migration version 5"
    }
    
    var isNeeded: Bool {
        return true
    }
    
    var version: Int {
        return 5
    }
    
    func run() throws {
        // Do some code
    }
}

final class TestProtocolMigration_2: MigrationProtocol {
    
    private var persistenceStorage: PersistenceStorage
    
    var description: String {
        "TestProtocolMigration number 2 with migration version 6"
    }
    
    var isNeeded: Bool {
        return true
    }
    
    var version: Int {
        return 6
    }
    
    func run() throws {
        // Do some code
        let versionCodeForMigration = persistenceStorage.versionCodeForMigration!
        persistenceStorage.versionCodeForMigration = versionCodeForMigration + 1
    }
    
    init(persistenceStorage: PersistenceStorage) {
        self.persistenceStorage = persistenceStorage
    }
}

final class TestProtocolMigration_3: MigrationProtocol {
    
    private var persistenceStorage: PersistenceStorage
    
    var description: String {
        "TestProtocolMigration number 3 with migration version 7"
    }
    
    var isNeeded: Bool {
        return true
    }
    
    var version: Int {
        return 7
    }
    
    func run() throws {
        // Do some code
        throw NSError(domain: "com.sdk.migration", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid version for migration"])
        let versionCodeForMigration = persistenceStorage.versionCodeForMigration!
        persistenceStorage.versionCodeForMigration = versionCodeForMigration + 1
    }
    
    init(persistenceStorage: PersistenceStorage) {
        self.persistenceStorage = persistenceStorage
    }
}
