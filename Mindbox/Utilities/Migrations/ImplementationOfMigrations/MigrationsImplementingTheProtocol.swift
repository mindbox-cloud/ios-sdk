//
//  MigrationsImplementingTheProtocol.swift
//  Mindbox
//
//  Created by Sergei Semko on 8/1/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation

final class Migration2_3: MigrationProtocol {
    
    private var persistenceStorage: PersistenceStorage
    
    var description: String {
        "Some description. Third migration"
    }
    
    var isNeeded: Bool {
        let versionCode = persistenceStorage.versionCodeForMigration ?? 0
        return versionCode < version
    }
    
    var version: Int {
        3
    }
    
    func run() throws {
        print("Performing migration")
    }
    
    init(persistenceStorage: PersistenceStorage) {
        self.persistenceStorage = persistenceStorage
    }
}
