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
        return isNotPresentingAnotherInApp() &&
               isUnderSessionLimit() &&
               isUnderDailyLimit() &&
               hasElapsedMinimumIntervalBetweenInApps()
    }
    
    func isNotPresentingAnotherInApp() -> Bool {
        guard !SessionTemporaryStorage.shared.isPresentingInAppMessage else {
            Logger.common(message: "[PresentationValidator] Another in-app is already being shown. Skip in-app", level: .debug, category: .inAppMessages)
            return false
        }
        return true
    }
    
    func isUnderSessionLimit() -> Bool {
        guard let maxInappsPerSession = SessionTemporaryStorage.shared.inAppSettings?.maxInappsPerSession else {
            Logger.common(message: "[PresentationValidator] No session inapp limit specified", level: .info, category: .inAppMessages)
            return true
        }
        
        guard maxInappsPerSession > 0 else {
            Logger.common(message: "[PresentationValidator] Session inapp limit is not positive (\(maxInappsPerSession)), treating as no limit", level: .info, category: .inAppMessages)
            return true
        }
        
        let currentShownCount = SessionTemporaryStorage.shared.sessionShownInApps.count
        let isAllowed = maxInappsPerSession > currentShownCount
        
        Logger.common(message: "[PresentationValidator] Inapp shown in session count: \(currentShownCount), limit: \(maxInappsPerSession), Show allowed: \(isAllowed)", level: .info, category: .inAppMessages)
        
        return isAllowed
    }
    
    func isUnderDailyLimit() -> Bool {
        guard let maxInappsPerDay = SessionTemporaryStorage.shared.inAppSettings?.maxInappsPerDay else {
            Logger.common(message: "[PresentationValidator] No daily inapp limit specified", level: .info, category: .inAppMessages)
            return true
        }
        
        guard maxInappsPerDay > 0 else {
            Logger.common(message: "[PresentationValidator] Daily inapp limit is not positive (\(maxInappsPerDay)), treating as no limit", level: .info, category: .inAppMessages)
            return true
        }
        
        guard let dictionary = persistenceStorage.shownInappsShowDatesDictionary, !dictionary.isEmpty else {
            Logger.common(message: "[PresentationValidator] No in-apps shown today", level: .info, category: .inAppMessages)
            return true
        }
        
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        
        var shownInappsToday = 0
        for dates in dictionary.values {
            for date in dates where calendar.isDate(date, inSameDayAs: today) {
                shownInappsToday += 1
            }
        }
        
        let isAllowed = maxInappsPerDay > shownInappsToday
        
        Logger.common(message: "[PresentationValidator] Total in-app shows today count: \(shownInappsToday), limit: \(maxInappsPerDay), Show allowed: \(isAllowed)", level: .info, category: .inAppMessages)
        
        return isAllowed
    }
    
    func hasElapsedMinimumIntervalBetweenInApps() -> Bool {
        return true
    }
}
