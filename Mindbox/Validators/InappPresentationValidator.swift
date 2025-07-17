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
    func canPresentInApp(isPriority: Bool, frequency: InappFrequency?, id: String) -> Bool
}

final class InAppPresentationValidator: InAppPresentationValidatorProtocol {
    private let persistenceStorage: PersistenceStorage
    
    init(persistenceStorage: PersistenceStorage) {
        self.persistenceStorage = persistenceStorage
    }
    
    func canPresentInApp(isPriority: Bool, frequency: InappFrequency?, id: String) -> Bool {
        Logger.common(message: "[PresentationValidator] Checking if can present in-app: \(id)", level: .debug, category: .inAppMessages)
        
        guard isNotPresentingAnotherInApp(), isValidFrequency(frequency: frequency, id: id) else {
            return false
        }

        if isPriority {
            let currentShownCount = SessionTemporaryStorage.shared.sessionShownInApps.count
            let shownInappsToday = getShownInappsTodayCount()
            
            Logger.common(message: """
                [PresentationValidator] Priority in-app detected, skipping all checks except isNotPresentingAnotherInApp
                - Current session shown count: \(currentShownCount)
                - Shown in-apps today: \(shownInappsToday)
                """, level: .debug, category: .inAppMessages)
            
            return true
        }
        
        return isUnderSessionLimit() &&
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
            Logger.common(message: "[PresentationValidator] [Session] No session inapp limit specified", level: .info, category: .inAppMessages)
            return true
        }
        
        guard maxInappsPerSession > 0 else {
            Logger.common(message: "[PresentationValidator] [Session] Inapp limit is not positive (\(maxInappsPerSession)), treating as no limit", level: .info, category: .inAppMessages)
            return true
        }
        
        let currentShownCount = SessionTemporaryStorage.shared.sessionShownInApps.count
        let isAllowed = maxInappsPerSession > currentShownCount
        
        Logger.common(message: "[PresentationValidator] [Session] Inapp shown in session count: \(currentShownCount), limit: \(maxInappsPerSession), Show allowed: \(isAllowed)", level: .info, category: .inAppMessages)
        
        return isAllowed
    }
    
    func isUnderDailyLimit() -> Bool {
        guard let maxInappsPerDay = SessionTemporaryStorage.shared.inAppSettings?.maxInappsPerDay else {
            Logger.common(message: "[PresentationValidator] [Daily] No daily inapp limit specified", level: .info, category: .inAppMessages)
            return true
        }
        
        guard maxInappsPerDay > 0 else {
            Logger.common(message: "[PresentationValidator] [Daily] Inapp limit is not positive (\(maxInappsPerDay)), treating as no limit", level: .info, category: .inAppMessages)
            return true
        }
        
        let shownInappsToday = getShownInappsTodayCount()
        let isAllowed = maxInappsPerDay > shownInappsToday
        
        Logger.common(message: "[PresentationValidator] [Daily] Total in-app shows today count: \(shownInappsToday), limit: \(maxInappsPerDay), Show allowed: \(isAllowed)", level: .info, category: .inAppMessages)
        
        return isAllowed
    }
    
    func hasElapsedMinimumIntervalBetweenInApps() -> Bool {
        guard let minIntervalString = SessionTemporaryStorage.shared.inAppSettings?.minIntervalBetweenShows,
              let minIntervalSeconds = try? minIntervalString.parseTimeSpanToSeconds() else {
            Logger.common(message: "[PresentationValidator] [minInterval] minIntervalBetweenShows not set or invalid, skipping interval check", level: .info, category: .inAppMessages)
            return true
        }
        
        guard minIntervalSeconds > 0 else {
            Logger.common(message: "[PresentationValidator] [minInterval] minIntervalBetweenShows is \(minIntervalSeconds), skipping interval check", level: .info, category: .inAppMessages)
            return true
        }
        
        guard let lastInappStateChangeDate = persistenceStorage.lastInappStateChangeDate else {
            Logger.common(message: "[PresentationValidator] [minInterval] lastInappStateChangeDate is nil, allow show", level: .info, category: .inAppMessages)
            return true
        }
        
        let minInterval = TimeInterval(minIntervalSeconds)
        let nextAllowedShowTime = lastInappStateChangeDate.addingTimeInterval(minInterval)
        let now = Date()
        let isAllowed = nextAllowedShowTime < now
        
        Logger.common(message: """
            [PresentationValidator] [minInterval]
            lastInappStateChangeDate: \(lastInappStateChangeDate.asDateTimeWithSeconds)
            minInterval: \(minInterval)s
            nextAllowedShowTime: \(nextAllowedShowTime.asDateTimeWithSeconds)
            now: \(now.asDateTimeWithSeconds)
            Show allowed: \(isAllowed)
            """)
        return isAllowed
    }
    
    func isValidFrequency(frequency: InappFrequency?, id: String) -> Bool {
        let frequencyValidator = InappFrequencyValidator(persistenceStorage: persistenceStorage)
        return frequencyValidator.isValid(frequency: frequency, id: id)
    }
    
    private func getShownInappsTodayCount() -> Int {
        guard let dictionary = persistenceStorage.shownDatesByInApp, !dictionary.isEmpty else {
            return 0
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
        
        return shownInappsToday
    }
}
