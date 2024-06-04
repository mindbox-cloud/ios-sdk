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
              let ttlMilliseconds = try? ttl.parseTimeSpanToMillis() else {
            Logger.common(message: "[TTL] Variables are missing or corrupted. Inapps reset will not be performed.")
            return false
        }
        
        let nowMilliseconds = Int64(Date().timeIntervalSince1970 * 1000)
        let configDownloadMilliseconds = configDownloadDate.timeIntervalSince1970 * 1000
        let expiredTimeTtl = Int64(ttlMilliseconds) + Int64(configDownloadMilliseconds)
        let isNeedResetInapps = nowMilliseconds > expiredTimeTtl

        let message = """
        [TTL] Current date: \(nowMilliseconds).
        Config with TTL valid until: \(expiredTimeTtl).
        Need to reset inapps: \(isNeedResetInapps).
        """
        
        Logger.common(message: message)
        return isNeedResetInapps
    }
}
