//
//  NotificationFormatFactory.swift
//  Mindbox
//
//  Created by vailence on 12.02.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
import NotificationCenter
import MindboxLogger

class NotificationStrategyFactory {
    static func strategy(for userInfo: [AnyHashable: Any]) -> NotificationFormatStrategy {
        if let aps = userInfo["aps"] as? [String: Any], aps["clickUrl"] != nil && aps["uniqueKey"] != nil {
            Logger.common(message: "NotificationStrategyFactory: Selected LegacyFormatStrategy for processing push notification.", level: .info, category: .notification)
            return LegacyFormatStrategy()
        }

        Logger.common(message: "NotificationStrategyFactory: Selected CurrentFormatStrategy for processing push notification.", level: .info, category: .notification)
        return CurrentFormatStrategy()
    }
}
