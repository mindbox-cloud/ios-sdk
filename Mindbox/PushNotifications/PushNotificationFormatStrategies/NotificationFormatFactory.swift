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
    static func strategy(for userInfo: [AnyHashable: Any]) -> NotificationFormatStrategy {
        if let aps = userInfo["aps"] as? [String: Any] {
            if aps["clickUrl"] != nil && aps["uniqueKey"] != nil {
                return LegacyFormatStrategy()
            }
        }
        
        return CurrentFormatStrategy()
    }
}
