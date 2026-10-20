//
//  BaseMigration.swift
//  Mindbox
//
//  Created by Sergei Semko on 7/29/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation

class BaseMigration: MigrationProtocol {

    var persistenceStorage: PersistenceStorage = DI.injectOrFail(PersistenceStorage.self)

    func performMigration() throws {
        fatalError("Subclasses must implement the `performMigration` method without calling super.")
    }

    // MARK: MigrationProtocol

    var description: String {
        fatalError("Subclasses must implement the `description` property.")
    }

    var isNeeded: Bool {
        fatalError("Subclasses must implement the `isNeeded` property.")
    }

    var version: Int {
        fatalError("Subclasses must implement the `version` property.")
    }

    final func run() throws {
        do {
            try performMigration()
            let versionCode = persistenceStorage.versionCodeForMigration ?? 0
            persistenceStorage.versionCodeForMigration = versionCode + 1
        } catch {
            throw error
        }
    }
}
