//
//  InappPresentationValidator.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 26.05.2025.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

protocol InAppPresentationValidatorProtocol {
    func canPresentInApp() -> Bool
}

final class InAppPresentationValidator: InAppPresentationValidatorProtocol {
    private let persistenceStorage: PersistenceStorage
    
    init(persistenceStorage: PersistenceStorage) {
        self.persistenceStorage = persistenceStorage
    }
    
    func canPresentInApp() -> Bool {
        return checkIsNotPresenting() &&
               checkSessionLimit() &&
               checkDailyLimit() &&
               checkMinimalIntervalBetweenInApps()
    }
    
    func checkIsNotPresenting() -> Bool {
        guard !SessionTemporaryStorage.shared.isPresentingInAppMessage else {
            Logger.common(message: "[PresentationValidator] Another in-app is already being shown. Skip in-app", level: .debug, category: .inAppMessages)
            return false
        }
        return true
    }
    
    func checkSessionLimit() -> Bool {
        guard let maxInappsPerSession = SessionTemporaryStorage.shared.inAppSettings?.maxInappsPerSession else {
            Logger.common(message: "[PresentationValidator] No session inapp limit specified", level: .info, category: .inAppMessages)
            return true
        }
        
        let currentShownCount = SessionTemporaryStorage.shared.sessionShownInApps.count
        let isAllowed = maxInappsPerSession > currentShownCount
        
        Logger.common(message: "[PresentationValidator] Inapp shown in session count: \(currentShownCount), limit: \(maxInappsPerSession), Show allowed: \(isAllowed)", level: .info, category: .inAppMessages)
        
        return isAllowed
    }
    
    func checkDailyLimit() -> Bool {
        return true // MARK: - Add logic here later.
    }
    
    func checkMinimalIntervalBetweenInApps() -> Bool {
        return true // MARK: - Add logic here later.
    }
}
