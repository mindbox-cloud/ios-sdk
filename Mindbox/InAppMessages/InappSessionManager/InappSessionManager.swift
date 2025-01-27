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
let expiredInappSession = "0.00:00:01.0000000"

final class InappSessionManager {
    private var lastTrackVisitTimestamp: Date?
    private let inappCoreManager: InAppCoreManagerProtocol
    private let inappConfigManager: InAppConfigurationManagerProtocol

    init(inappCoreManager: InAppCoreManagerProtocol, inappConfigManager: InAppConfigurationManagerProtocol) {
        self.inappCoreManager = inappCoreManager
        self.inappConfigManager = inappConfigManager
    }

    func checkInappSession() {
        return
        Logger.common(message: "[InappSessionManager] checkInappSession called")

        guard let lastTrackVisitTimestamp = lastTrackVisitTimestamp else {
            self.lastTrackVisitTimestamp = Date()
            Logger.common(message: "[InappSessionManager] lastTrackVisitTimestamp is nil, setting it to current timestamp: \(Date())")
            return
        }

        guard let expiredInappTime = try? expiredInappSession.parseTimeSpanToMillis(), expiredInappTime > 0 else {
            Logger.common(message: "[InappSessionManager] expiredInappTime is nil or invalid — do nothing")
            return
        }

        let now = Date()
        if now > lastTrackVisitTimestamp.addingTimeInterval(Double(expiredInappTime) / 1000) {
            Logger.common(message: "[InappSessionManager] In-app session has expired. Last visit timestamp: \(String(describing: self.lastTrackVisitTimestamp)). Current time: \(now). Updating session...")
            updateInappSession()
        } else {
            Logger.common(message: "[InappSessionManager] In-app session not yet expired. Last visit timestamp: \(String(describing: self.lastTrackVisitTimestamp)). Current time: \(now). No update needed.")
        }

        self.lastTrackVisitTimestamp = now
    }

    private func updateInappSession() {
        inappCoreManager.isConfigurationReady = false
        inappCoreManager.sendEvent(.applicationEvent(ApplicationEvent(name: "Hello", model: nil)))
        inappCoreManager.sendEvent(.start)
        inappConfigManager.prepareConfiguration()
    }
}
