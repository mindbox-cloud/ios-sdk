//
//  InappSessionManager.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 24.01.2025.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import UIKit
import MindboxLogger

protocol InappSessionManagerProtocol {
    func checkInappSession()
}

final class InappSessionManager: InappSessionManagerProtocol {
    
    var lastTrackVisitTimestamp: Date?
    
    private let inappCoreManager: InAppCoreManagerProtocol
    private let inappConfigManager: InAppConfigurationManagerProtocol
    private let targetingChecker: TargetingCheckerEraseProtocol
    private let userVisitManager: UserVisitManagerProtocol
    private let inappTrackingService: InAppTrackingServiceProtocol

    init(inappCoreManager: InAppCoreManagerProtocol,
         inappConfigManager: InAppConfigurationManagerProtocol,
         targetingChecker: TargetingCheckerEraseProtocol,
         userVisitManager: UserVisitManagerProtocol,
         inappTrackingService: InAppTrackingServiceProtocol) {
        self.inappCoreManager = inappCoreManager
        self.inappConfigManager = inappConfigManager
        self.targetingChecker = targetingChecker
        self.userVisitManager = userVisitManager
        self.inappTrackingService = inappTrackingService
        
        addObserverToDismissInApp()
    }

    func checkInappSession() {
        let isSDKInitialized = SessionTemporaryStorage.shared.isInitializationCalled
        if !isSDKInitialized {
            return
        }
        
        let now = Date()
        var updatingInappSession = false
        
        defer {
            if isSDKInitialized {
                lastTrackVisitTimestamp = now
                Logger.common(message: "[InappSessionManager] Updating lastTrackVisitTimestamp to \(now.asDateTimeWithSeconds).")
                
                if !updatingInappSession {
                    logNearestInappSessionExpirationTime()
                }
            }
        }

        guard let lastTimestamp = lastTrackVisitTimestamp else {
            Logger.common(message: "[InappSessionManager] lastTrackVisitTimestamp is nil — skip session expiration check.")
            return
        }
        
        guard let sessionTimeInSeconds = getConfigSession(), sessionTimeInSeconds > 0 else {
            Logger.common(message: "[InappSessionManager] expiredInappTime is nil/invalid or <= 0 — skip session expiration check.")
            return
        }

        let timeBetweenVisitsSeconds = now.timeIntervalSince(lastTimestamp)
        if timeBetweenVisitsSeconds > Double(sessionTimeInSeconds) {
            updatingInappSession = true
            Logger.common(message: "[InappSessionManager] Session expired. Need to update session...")
            updateInappSession()
        } else {
            Logger.common(message: "[InappSessionManager] Session not expired.")
        }
    }

    private func updateInappSession() {
        hideInappIfInappSessionExpired()
        resetCacheAndSessionFlags()
        
        userVisitManager.saveUserVisit()
        
        inappCoreManager.sendEvent(.start)
        inappConfigManager.prepareConfiguration()
        Logger.common(message: "[InappSessionManager] Update inapp session.")
    }
    
    private func resetCacheAndSessionFlags() {
        inappCoreManager.discardEvents()
        SessionTemporaryStorage.shared.erase()
        targetingChecker.eraseCache()
    }

    private func hideInappIfInappSessionExpired() {
        Logger.common(message: "[InappSessionManager] Hide previous inapp because session expired.")
        NotificationCenter.default.post(name: .shouldDiscardInapps, object: nil)
        if SessionTemporaryStorage.shared.isPresentingInAppMessage {
            inappTrackingService.saveInappStateChange()
        }
    }
    
    private func getConfigSession() -> Double? {
        guard let configSession = SessionTemporaryStorage.shared.expiredConfigSession,
              let sessionTimeInSeconds = try? configSession.parseTimeSpanToSeconds() else {
            return nil
        }
        
        return Double(sessionTimeInSeconds)
    }
    
    private func addObserverToDismissInApp() {
        NotificationCenter.default.addObserver(
            forName: .mobileConfigDownloaded,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.logNearestInappSessionExpirationTime()
        }
    }
    
    private func logNearestInappSessionExpirationTime() {
        if let lastTrackVisitTimestamp = lastTrackVisitTimestamp,
           let sessionTimeInSeconds = self.getConfigSession(), sessionTimeInSeconds > 0 {
            let expirationDate = lastTrackVisitTimestamp.addingTimeInterval(sessionTimeInSeconds)
            SessionTemporaryStorage.shared.configSessionExpirationTime = expirationDate
            Logger.common(message: "[InappSessionManager] Nearest session expiration time is \(expirationDate.asDateTimeWithSeconds).")
        }
    }
}
