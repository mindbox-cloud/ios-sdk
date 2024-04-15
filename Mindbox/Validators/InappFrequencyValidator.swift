//
//  InappFrequencyValidator.swift
//  Mindbox
//
//  Created by vailence on 11.04.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation

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
        let shownInAppsIds = persistenceStorage.shownInappsDictionary ?? [:]
        switch item.kind {
            case .lifetime:
                return shownInAppsIds[id] == nil
            case .session:
                if let savedTime = shownInAppsIds[id], Date() < savedTime {
                    return false
                }
                
                return true
        }
    }
}

class PeriodicFrequencyValidator {
    let persistenceStorage: PersistenceStorage
    
    init(persistenceStorage: PersistenceStorage) {
        self.persistenceStorage = persistenceStorage
    }
    
    func isValid(item: PeriodicFrequency, id: String) -> Bool {
        let currentDate = Date()
        guard let inappsDict = persistenceStorage.shownInappsDictionary else {
            return false
        }
        
        guard let shownDate = inappsDict[id] else {
            return true
        }
        
        let calendar = Calendar.current
        var shownDatePlusFrequency: Date?
        switch item.unit {
            case .seconds:
                shownDatePlusFrequency = calendar.date(byAdding: .second, value: item.value, to: shownDate)
            case .minutes:
                shownDatePlusFrequency = calendar.date(byAdding: .minute, value: item.value, to: shownDate)
            case .hours:
                shownDatePlusFrequency = calendar.date(byAdding: .hour, value: item.value, to: shownDate)
            case .days:
                shownDatePlusFrequency = calendar.date(byAdding: .day, value: item.value, to: shownDate)
        }
        
        guard let shownDatePlusFrequency = shownDatePlusFrequency else {
            return false
        }
        
        return currentDate > shownDatePlusFrequency
    }
}
