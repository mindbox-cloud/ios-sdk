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
        
        guard let ttl = config.settings?.ttl?.inapps,
              let ttlMilliseconds = try? ttl.parseTimeSpanToMillis() else {
            Logger.common(message: "[TTL] Variables are missing or corrupted. Inapps reset will not be performed.")
            return false
        }
        
        let now = Date()
        let nowMilliseconds = Int64(now.timeIntervalSince1970 * 1000)
        let configDownloadMilliseconds = configDownloadDate.timeIntervalSince1970 * 1000
        let expiredTimeTtlMilliseconds = Int64(ttlMilliseconds) + Int64(configDownloadMilliseconds)
        let isNeedResetInapps = nowMilliseconds > expiredTimeTtlMilliseconds

        let expiredTimeTtlDate = Date(timeIntervalSince1970: TimeInterval(expiredTimeTtlMilliseconds) / 1000.0)
        
        let message = """
        [TTL] Current date: \(now.asDateTimeWithSeconds).
        Config with TTL valid until: \(expiredTimeTtlDate.asDateTimeWithSeconds).
        Need to reset inapps: \(isNeedResetInapps).
        """
        
        Logger.common(message: message)
        return isNeedResetInapps
    }
}
