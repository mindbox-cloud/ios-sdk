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
        if let aps = userInfo["aps"] as? [String: Any] {
            if aps["clickUrl"] != nil && aps["uniqueKey"] != nil {
                Logger.common(message: "Legacy push notification format.", level: .debug, category: .notification)
                return LegacyFormatStrategy()
            }
        }
        
        return CurrentFormatStrategy()
    }
}
