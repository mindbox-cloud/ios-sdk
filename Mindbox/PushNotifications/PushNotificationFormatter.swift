//
//  PushNotificationFormatter.swift
//  Mindbox
//
//  Created by vailence on 12.02.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
import NotificationCenter
import MindboxLogger

class NotificationFormatter {
    static func formatNotification(_ notification: UNNotification) -> MBPushNotification? {
        let strategy = NotificationStrategyFactory.strategy(for: notification)
        let userInfo = notification.request.content.userInfo
        return strategy.handle(userInfo: userInfo)
    }
}
