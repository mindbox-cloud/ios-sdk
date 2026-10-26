//
//  InappSessionManager.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 24.01.2025.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import UIKit
import QuartzCore
import MindboxLogger

protocol InappSessionManagerProtocol {
    func checkInappSession()
}

final class InappSessionManager: InappSessionManagerProtocol {
    
    @Locked var lastTrackVisitTimestamp: Date?

    private let sessionCheck = NSLock()
    
    private let inappCoreManager: InAppCoreManagerProtocol
    private let inappConfigManager: InAppConfigurationManagerProtocol
    private let targetingChecker: TargetingCheckerEraseProtocol
    private let userVisitManager: UserVisitManagerProtocol

    init(inappCoreManager: InAppCoreManagerProtocol,
         inappConfigManager: InAppConfigurationManagerProtocol,
         targetingChecker: TargetingCheckerEraseProtocol,
         userVisitManager: UserVisitManagerProtocol) {
        self.inappCoreManager = inappCoreManager
        self.inappConfigManager = inappConfigManager
        self.targetingChecker = targetingChecker
        self.userVisitManager = userVisitManager
        
        addObserverToDismissInApp()
    }

    func checkInappSession() {
        sessionCheck.lock()
        defer { sessionCheck.unlock() }

        let check = decideOnTheSession()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .inappSessionChecked,
                                            object: nil,
                                            userInfo: [Constants.Notification.sessionCheckStartedAt: check.startedAt,
                                                       Constants.Notification.startsNewSession: check.startsNewSession])
        }
    }

    private func decideOnTheSession() -> (startedAt: TimeInterval, startsNewSession: Bool) {
        let startedAt = CACurrentMediaTime()
        guard SessionTemporaryStorage.shared.isInitializationCalled else {
            return (startedAt, false)
        }
        
        let now = Date()
        let sessionTime = getConfigSession().flatMap { $0 > 0 ? $0 : nil }
        let visit = SessionTemporaryStorage.shared.$ledger.mutate { ledger -> (previous: Date?, isExpired: Bool) in
            guard let previous = $lastTrackVisitTimestamp.exchange(now) else { return (nil, false) }
            guard let sessionTime, now.timeIntervalSince(previous) > sessionTime else { return (previous, false) }

            ledger.isSessionEnding = true
            return (previous, true)
        }
        Logger.common(message: "[InappSessionManager] Updating lastTrackVisitTimestamp to \(now.asDateTimeWithSeconds).")

        defer {
            if !visit.isExpired {
                logNearestInappSessionExpirationTime()
            }
        }

        guard visit.previous != nil else {
            Logger.common(message: "[InappSessionManager] lastTrackVisitTimestamp is nil — skip session expiration check.")
            return (startedAt, false)
        }
        
        guard sessionTime != nil else {
            Logger.common(message: "[InappSessionManager] expiredInappTime is nil/invalid or <= 0 — skip session expiration check.")
            return (startedAt, false)
        }

        if visit.isExpired {
            Logger.common(message: "──────────────── [New session] ────────────────", level: .info, category: .general)
            Logger.common(message: "[InappSessionManager] Session expired. Need to update session...")
            updateInappSession()
        } else {
            Logger.common(message: "[InappSessionManager] Session not expired.")
        }

        return (startedAt, visit.isExpired)
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
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .shouldDiscardInapps, object: nil)
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
