//
//  InappTrackingService.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 03.06.2025.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

protocol InAppTrackingServiceProtocol {
    func trackInAppShown(id: String)
    func saveLastShownTimestamp()
}

final class InAppTrackingService: InAppTrackingServiceProtocol {
    private let persistenceStorage: PersistenceStorage
    private let calendar: Calendar
    
    init(persistenceStorage: PersistenceStorage, calendar: Calendar = .current) {
        self.persistenceStorage = persistenceStorage
        self.calendar = calendar
    }
    
    func trackInAppShown(id: String) {
        let now = Date()
        
        trackInAppInSession(id: id)
        updateShownDates(id: id, newDate: now)
        cleanupOldDates(id: id, currentDate: now)
    }
    
    func saveLastShownTimestamp() {
        let now = Date()
        persistenceStorage.lastShownInappDate = now
        Logger.common(message: "[InAppTrackingService] Updated lastShownInappDate to \(now.asDateTimeWithSeconds)", level: .info, category: .inAppMessages)
    }
    
    private func trackInAppInSession(id: String) {
        SessionTemporaryStorage.shared.sessionShownInApps.append(id)
    }
    
    private func updateShownDates(id: String, newDate: Date) {
        var currentDates = persistenceStorage.shownDatesByInApp?[id] ?? []
        currentDates.append(newDate)
        persistenceStorage.shownDatesByInApp?[id] = currentDates
    }
    
    private func cleanupOldDates(id: String, currentDate: Date) {
        guard var currentDates = persistenceStorage.shownDatesByInApp?[id] else { return }
        guard let cutoffDate = calendar.date(
            byAdding: .day,
            value: -Constants.MagicNumbers.daysToKeepInappShowTimes,
            to: currentDate
        ) else { return }

        let datesToRemove = currentDates.filter { $0 <= cutoffDate }
        if !datesToRemove.isEmpty {
            currentDates = currentDates.filter { $0 > cutoffDate }
            Logger.common(message: """
                            [InAppTrackingService] Removed \(datesToRemove.count) old dates for in-app \(id):
                            \(datesToRemove.map { $0.asDateTimeWithSeconds }.joined(separator: ", "))
                            """, level: .info, category: .inAppMessages)
            persistenceStorage.shownDatesByInApp?[id] = currentDates
        }
    }
}
