//
//  InappSessionManager.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 24.01.2025.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import UIKit
import MindboxLogger

// TODO: - Уйдет в параметр с бэка в следующих задачах
let expiredInappSession = "0.00:00:30.0000000"

final class InappSessionManager {
    private var lastTrackVisitTimestamp: Date?
    private let inappCoreManager: InAppCoreManagerProtocol
    private let inappConfigManager: InAppConfigurationManagerProtocol

    init(inappCoreManager: InAppCoreManagerProtocol, inappConfigManager: InAppConfigurationManagerProtocol) {
        self.inappCoreManager = inappCoreManager
        self.inappConfigManager = inappConfigManager
    }

    func checkInappSession() {
        Logger.common(message: "[InappSessionManager] checkInappSession called")

        let now = Date()

        defer {
            lastTrackVisitTimestamp = now
            Logger.common(message: "[InappSessionManager] Updating lastTrackVisitTimestamp to \(now.asDateTimeWithSeconds).")
        }

        guard let lastTimestamp = lastTrackVisitTimestamp else {
            Logger.common(message: "[InappSessionManager] lastTrackVisitTimestamp is nil — skip session expiration check.")
            return
        }

        guard let sessionTimeInSeconds = try? expiredInappSession.parseTimeStampToSeconds(), sessionTimeInSeconds > 0 else {
            Logger.common(message: "[InappSessionManager] expiredInappTime is nil/invalid or <= 0 — skip session expiration check.")
            return
        }

        let timeBetweenVisitsSeconds = now.timeIntervalSince(lastTimestamp)
        if timeBetweenVisitsSeconds > Double(sessionTimeInSeconds) {
            Logger.common(message: "[InappSessionManager] Session expired. Need to update session...")
            updateInappSession()
        } else {
            Logger.common(message: "[InappSessionManager] Session not expired.")
        }
    }

    private func updateInappSession() {
        Logger.common(message: "[InappSessionManager] Update inapp session.")
        hideInappIfInappSessionExpired()

        inappCoreManager.discardEvents()
        inappCoreManager.sendEvent(.start)
        inappConfigManager.prepareConfiguration()
    }

    private func hideInappIfInappSessionExpired() {
        Logger.common(message: "[InappSessionManager] Hide previous inapp because session expired.")
        NotificationCenter.default.post(name: Notification.Name("shouldDiscardInapps"), object: nil)
    }
}
