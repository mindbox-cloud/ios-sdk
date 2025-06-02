//
//  InappFrequencyValidator.swift
//  Mindbox
//
//  Created by vailence on 11.04.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

class InappFrequencyValidator: Validator {
    typealias T = InApp

    let persistenceStorage: PersistenceStorage

    init(persistenceStorage: PersistenceStorage) {
        self.persistenceStorage = persistenceStorage
    }

    func isValid(item: InApp) -> Bool {
        guard let frequency = item.frequency else {
            return false
        }

        switch frequency {
            case .periodic(let periodicFrequency):
                let validator = PeriodicFrequencyValidator(persistenceStorage: persistenceStorage)
                return validator.isValid(item: periodicFrequency, id: item.id)
            case .once(let onceFrequency):
                let validator = OnceFrequencyValidator(persistenceStorage: persistenceStorage)
                return validator.isValid(item: onceFrequency, id: item.id)
            case .unknown:
                return false
        }
    }
}

class OnceFrequencyValidator {
    let persistenceStorage: PersistenceStorage

    init(persistenceStorage: PersistenceStorage) {
        self.persistenceStorage = persistenceStorage
    }

    func isValid(item: OnceFrequency, id: String) -> Bool {
        let shownInappsShowDatesDictionary = persistenceStorage.shownInappsShowDatesDictionary ?? [:]
        var result = false
        switch item.kind {
            case .lifetime:
                result = shownInappsShowDatesDictionary[id] == nil
            case .session:
                if SessionTemporaryStorage.shared.sessionShownInApps.contains(id) {
                    Logger.common(message: "[Inapp frequency] Inapp ID \(id) is already shown in this session. Skip this in-app.",
                                  level: .debug, category: .inAppMessages)
                    result = false
                } else {
                    result = true
                }
        }

        Logger.common(message: "[Inapp frequency] Current frequency is [once] and kind is [\(item.kind.rawValue)]. Valid = \(result). Inapp ID: \(id)",
                      level: .debug, category: .inAppMessages)
        return result
    }
}

class PeriodicFrequencyValidator {
    let persistenceStorage: PersistenceStorage

    init(persistenceStorage: PersistenceStorage) {
        self.persistenceStorage = persistenceStorage
    }

    func isValid(item: PeriodicFrequency, id: String) -> Bool {
        guard item.value > 0 else {
            Logger.common(message: """
            [Inapp frequency] Current frequency is [periodic], it's unit is [\(item.unit.rawValue)].
            Value (\(item.value)) is zero or negative.
            Inapp ID \(id) is not valid.
            """, level: .info, category: .inAppMessages)
            return false
        }

        let currentDate = Date()
        guard let inappsDict = persistenceStorage.shownInappsShowDatesDictionary else {
            Logger.common(message: "shownInappsShowDatesDictionary not exists. Inapp ID \(id) is not valid.", level: .error, category: .inAppMessages)
            return false
        }

        guard let shownDates = inappsDict[id], !shownDates.isEmpty else {
            Logger.common(message: """
            [Inapp frequency] Current frequency is [periodic] and unit is [\(item.unit.rawValue)].
            Inapp ID \(id) is never shown before.
            Keeping in-app.
            """, level: .info, category: .inAppMessages)
            return true
        }

        let calendar = Calendar.current
        let component = item.unit.calendarComponent
        let lastShownDate = shownDates.max() ?? Date()
        if let shownDatePlusFrequency = calendar.date(byAdding: component, value: item.value, to: lastShownDate) {
            let isValid = currentDate > shownDatePlusFrequency
            Logger.common(message: """
            [Inapp frequency] Current frequency is [periodic] and unit is [\(item.unit.rawValue)] value is (\(item.value)).
            Last shown date plus frequency: \(shownDatePlusFrequency.asDateTimeWithSeconds).
            Current date: \(currentDate.asDateTimeWithSeconds).
            Inapp ID \(id) valid = \(isValid)
            """, level: .debug, category: .inAppMessages)
            return isValid
        } else {
            Logger.common(message: "Failed to calculate the next valid show date for Inapp ID \(id).", level: .error, category: .inAppMessages)
            return false
        }
    }
}
