//
//  NotificationFormatFactory.swift
//  Mindbox
//
//  Created by vailence on 12.02.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
import NotificationCenter

class NotificationStrategyFactory {
    static func strategy(for notification: UNNotification) -> NotificationFormatStrategy {
        let userInfo = notification.request.content.userInfo
        
        if let aps = userInfo["aps"] as? [String: Any],
           aps.keys.contains(where: { ["clickUrl", "uniqueKey"].contains($0) }) {
            return LegacyFormatStrategy()
        } else {
            return CurrentFormatStrategy()
        }
    }
}
