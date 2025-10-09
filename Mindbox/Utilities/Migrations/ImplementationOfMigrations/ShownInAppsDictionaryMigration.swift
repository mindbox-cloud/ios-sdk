//
//  ShownInAppsDictionaryMigration.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 03.06.2025.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

final class ShownInAppsDictionaryMigration: MigrationProtocol {

    private var persistenceStorage: PersistenceStorage = DI.injectOrFail(PersistenceStorage.self)

    var description: String {
        "Migration shownInappsDictionary to shownDatesByInApp. Starting with SDK 2.14.0."
    }

    @available(*, deprecated, message: "Suppress `deprecated` shownInappsDictionary warning")
    var isNeeded: Bool {
        persistenceStorage.shownInappsDictionary?.isEmpty == false
    }

    var version: Int {
        1
    }

    @available(*, deprecated, message: "Suppress deprecated `shownInappsDictionary` warning")
    func run() throws {
        guard let oldShownInappsDictionary = persistenceStorage.shownInappsDictionary else {
            Logger.common(message: "[Migrations] Skip shownInappsDictionary migration: no old format data to migrate", level: .info, category: .migration)
            return
        }

        var newFormatShownInapps = [String: [Date]]()

        for (id, date) in oldShownInappsDictionary {
            newFormatShownInapps[id] = [date]
        }

        persistenceStorage.shownDatesByInApp = newFormatShownInapps
        persistenceStorage.shownInappsDictionary = nil
    }
}
