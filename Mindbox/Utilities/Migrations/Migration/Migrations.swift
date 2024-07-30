//
//  Migrations.swift
//  Mindbox
//
//  Created by Sergei Semko on 7/29/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation

final class Migration1: BaseMigration {
    
    override var description: String {
        "Some description. First migration"
    }
    
    override var isNeeded: Bool {
        let versionCode = persistenceStorage.versionCodeForMigration ?? 0
        return versionCode < MigrationConstants.sdkVersionCode
    }
    
    override var version: Int {
        1
    }
    
    override func performMigration() throws {
        print("Performing migration")
    }
}


final class Migration2: BaseMigration {
    
    override var description: String {
        "Second migration"
    }
    
    override var isNeeded: Bool {
        let versionCode = persistenceStorage.versionCodeForMigration ?? 0
        return versionCode < MigrationConstants.sdkVersionCode
    }
    
    override var version: Int {
        return 2
    }
    
    override func performMigration() throws {
        print("Performing migration")
    }
}
