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
    func trackInAppShown(id: String, in history: inout InappShowHistory)
    func saveInappStateChange(in history: inout InappShowHistory)
}

final class InAppTrackingService: InAppTrackingServiceProtocol {
    private let calendar: Calendar
    
    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }
    
    func trackInAppShown(id: String, in history: inout InappShowHistory) {
        let now = Date()

        updateShownDates(id: id, newDate: now, in: &history)
        cleanupOldDates(id: id, currentDate: now, in: &history)
    }
    
    func saveInappStateChange(in history: inout InappShowHistory) {
        
        let now = Date()
        history.lastStateChangeDate = now
        Logger.common(message: "[InAppTrackingService] Updated lastInappStateChangeDate to \(now.asDateTimeWithSeconds)", level: .info, category: .inAppMessages)
    }
    
    private func updateShownDates(id: String, newDate: Date, in history: inout InappShowHistory) {
        var currentDates = history.shownDatesByInApp?[id] ?? []
        currentDates.append(newDate)
        history.shownDatesByInApp?[id] = currentDates
    }
    
    private func cleanupOldDates(id: String, currentDate: Date, in history: inout InappShowHistory) {
        guard var currentDates = history.shownDatesByInApp?[id] else { return }
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
            history.shownDatesByInApp?[id] = currentDates
        }
    }
}
