//
//  TTLValidationService.swift
//  Mindbox
//
//  Created by vailence on 29.03.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

protocol TTLValidationProtocol {
    func needResetInapps(config: ConfigResponse) -> Bool
}

class TTLValidationService: TTLValidationProtocol {
    
    let persistenceStorage: PersistenceStorage
    
    init(persistenceStorage: PersistenceStorage) {
        self.persistenceStorage = persistenceStorage
    }
    
    func needResetInapps(config: ConfigResponse) -> Bool {
        guard let configDownloadDate = persistenceStorage.configDownloadDate else {
            Logger.common(message: "[TTL] Config download date is nil. Unable to proceed with inapps reset validation.")
            return false
        }
        
        let now = Date()
        
        guard let ttl = config.settings?.ttl?.inapps,
              let downloadConfigDateWithTTL = getDateWithIntervalByType(ttl: ttl, date: configDownloadDate) else {
            Logger.common(message: "[TTL] Variables are missing or corrupted. Inapps reset will not be performed.")
            return false
        }
        
        let calendar = Calendar.current
        let nowComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: now)
        let ttlComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: downloadConfigDateWithTTL)
        
        guard let nowWithoutMilliseconds = calendar.date(from: nowComponents),
              let downloadConfigDateWithTTLWithoutMilliseconds = calendar.date(from: ttlComponents) else {
            Logger.common(message: "[TTL] Error in date components. Inapps reset will not be performed.")
            return false
        }

        let message = """
        [TTL] Current date: \(nowWithoutMilliseconds.asDateTimeWithSeconds).
        Config with TTL valid until: \(downloadConfigDateWithTTLWithoutMilliseconds.asDateTimeWithSeconds).
        Need to reset inapps: \(nowWithoutMilliseconds > downloadConfigDateWithTTLWithoutMilliseconds).
        """
        
        Logger.common(message: message)
        return nowWithoutMilliseconds > downloadConfigDateWithTTLWithoutMilliseconds
    }
    
    private func getDateWithIntervalByType(ttl: Settings.TimeToLive.TTLUnit, date: Date) -> Date? {
        guard let type = ttl.unit, let value = ttl.value else {
            Logger.common(message: "[TTL] Unable to calculate the date with TTL. The unit or value is missing.")
            return nil
        }
        
        let calendar = Calendar.current
        switch type {
            case .seconds:
                return calendar.date(byAdding: .second, value: value, to: date)
            case .minutes:
                return calendar.date(byAdding: .minute, value: value, to: date)
            case .hours:
                return calendar.date(byAdding: .hour, value: value, to: date)
            case .days:
                return calendar.date(byAdding: .day, value: value, to: date)
        }
    }
}
