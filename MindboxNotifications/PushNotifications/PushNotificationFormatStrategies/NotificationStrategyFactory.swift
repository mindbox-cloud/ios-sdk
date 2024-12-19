//
//  NotificationStrategyFactory.swift
//  MindboxNotifications
//
//  Created by Sergei Semko on 8/15/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

final class NotificationStrategyFactory {
    static func strategy(for userInfo: [AnyHashable: Any]) -> NotificationFormatStrategy {
        if let aps = userInfo["aps"] as? [String: Any], aps["clickUrl"] != nil && aps["uniqueKey"] != nil {
            Logger.common(message: "[NotificationServiceChecker] NotificationStrategyFactory: Selected LegacyFormatStrategy for processing push notification.", level: .info, category: .notification)
            return LegacyFormatStrategy()
        }

        Logger.common(message: "[NotificationServiceChecker] NotificationStrategyFactory: Selected CurrentFormatStrategy for processing push notification.", level: .info, category: .notification)
        return CurrentFormatStrategy()
    }
}
