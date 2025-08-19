//
//  NotificationStrategyFactory.swift
//  MindboxNotifications
//
//  Created by Sergei Semko on 8/15/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation

final class NotificationStrategyFactory {
    static func strategy(for userInfo: [AnyHashable: Any]) -> NotificationFormatStrategy {
        if let aps = userInfo["aps"] as? [String: Any], aps["clickUrl"] != nil && aps["uniqueKey"] != nil {
            return LegacyFormatStrategy()
        }

        return CurrentFormatStrategy()
    }
}
