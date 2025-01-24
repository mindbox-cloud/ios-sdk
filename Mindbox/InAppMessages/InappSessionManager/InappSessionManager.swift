//
//  InappSessionManager.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 24.01.2025.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import UIKit

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
        guard let lastTrackVisitTimestamp = lastTrackVisitTimestamp else {
            lastTrackVisitTimestamp = Date()
            return
        }

        guard let expiredInappTime = try? expiredInappSession.parseTimeSpanToMillis(), expiredInappTime > 0 else {
            return
        }

        let now = Date()
        if now > lastTrackVisitTimestamp.addingTimeInterval(Double(expiredInappTime) / 1000) {
            updateInappSession()
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
