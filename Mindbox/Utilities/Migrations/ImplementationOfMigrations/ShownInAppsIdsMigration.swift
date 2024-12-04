//
//  ShownInAppsIdsMigration.swift
//  Mindbox
//
//  Created by Sergei Semko on 8/29/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation

final class MigrationShownInAppsIds: MigrationProtocol {

    private var persistenceStorage: PersistenceStorage = DI.injectOrFail(PersistenceStorage.self)

    var description: String {
        "Migration shownInAppsIds to shownInappsDictionary. Starting with SDK 2.10.0."
    }

    @available(*, deprecated, message: "Suppress `deprecated` shownInAppsIds warning")
    var isNeeded: Bool {
        persistenceStorage.shownInAppsIds?.isEmpty == false
    }

    var version: Int {
        0
    }

    @available(*, deprecated, message: "Suppress deprecated `shownInAppsIds` warning")
    func run() throws {
        guard let oldShownInAppsIds = persistenceStorage.shownInAppsIds else {
            return
        }

        let migrationTimestamp = Date(timeIntervalSince1970: 0)
        var newFormatShownInapps = [String: Date]()

        for id in oldShownInAppsIds {
            newFormatShownInapps[id] = migrationTimestamp
        }

        persistenceStorage.shownInappsDictionary = newFormatShownInapps
        persistenceStorage.shownInAppsIds = nil
    }
}
