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
    
    private func trackInAppInSession(id: String) {
        SessionTemporaryStorage.shared.sessionShownInApps.append(id)
    }
    
    private func updateShownDates(id: String, newDate: Date) {
        var currentDates = persistenceStorage.shownInappsShowDatesDictionary?[id] ?? []
        currentDates.append(newDate)
        persistenceStorage.shownInappsShowDatesDictionary?[id] = currentDates
    }
    
    private func cleanupOldDates(id: String, currentDate: Date) {
        guard var currentDates = persistenceStorage.shownInappsShowDatesDictionary?[id] else { return }
        
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: currentDate)!
        currentDates = currentDates.filter { date in
            date > twoDaysAgo
        }
        
        persistenceStorage.shownInappsShowDatesDictionary?[id] = currentDates
    }
}
