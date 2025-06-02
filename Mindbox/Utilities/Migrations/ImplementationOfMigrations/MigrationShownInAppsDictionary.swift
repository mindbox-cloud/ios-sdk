//
//  MigrationShownInAppsDictionary.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 03.06.2025.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import Foundation

final class MigrationShownInAppsDictionary: MigrationProtocol {

    private var persistenceStorage: PersistenceStorage = DI.injectOrFail(PersistenceStorage.self)

    var description: String {
        "Migration shownInappsDictionary to shownInappsShowDatesDictionary. Starting with SDK 2.14.0."
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
            return
        }

        var newFormatShownInapps = [String: [Date]]()

        for (id, date) in oldShownInappsDictionary {
            newFormatShownInapps[id] = [date]
        }

        persistenceStorage.shownInappsShowDatesDictionary = newFormatShownInapps
        persistenceStorage.shownInappsDictionary = nil
    }
}
