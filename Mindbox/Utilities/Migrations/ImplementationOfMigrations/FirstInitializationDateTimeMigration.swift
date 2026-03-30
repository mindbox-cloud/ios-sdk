//
//  FirstInitializationDateTimeMigration.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 12.03.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

final class FirstInitializationDateTimeMigration: MigrationProtocol {

    private let persistenceStorage: PersistenceStorage = DI.injectOrFail(PersistenceStorage.self)

    var description: String {
        "Migration fills firstInitializationDateTime from installationDate. Starting with SDK 2.15.0."
    }

    var isNeeded: Bool {
        persistenceStorage.firstInitializationDateTime == nil
            && persistenceStorage.installationDate != nil
    }

    var version: Int {
        4
    }

    func run() throws {
        guard persistenceStorage.firstInitializationDateTime == nil else { return }
        persistenceStorage.firstInitializationDateTime = persistenceStorage.installationDate ?? Date()
    }
}
