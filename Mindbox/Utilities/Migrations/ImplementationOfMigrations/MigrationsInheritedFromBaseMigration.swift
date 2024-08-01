//
//  MigrationsInheritedFromBaseMigration.swift
//  Mindbox
//
//  Created by Sergei Semko on 7/29/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation

final class Migration0_1: BaseMigration {
    
    override var description: String {
        "Some description. First migration"
    }
    
    override var isNeeded: Bool {
        let versionCode = persistenceStorage.versionCodeForMigration ?? 0
        return versionCode < version
    }
    
    override var version: Int {
        1
    }
    
    override func performMigration() throws {
        print("Performing migration")
    }
}


final class Migration1_2: BaseMigration {
    
    override var description: String {
        "Second migration"
    }
    
    override var isNeeded: Bool {
        let versionCode = persistenceStorage.versionCodeForMigration ?? 0
        return versionCode < version
    }
    
    override var version: Int {
        return 2
    }
    
    override func performMigration() throws {
        print("Performing migration")
    }
}
