//
//  NotificationFormatter.swift
//  MindboxNotifications
//
//  Created by Sergei Semko on 8/15/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation

final class NotificationFormatter {
    static func formatNotification(_ userInfo: [AnyHashable: Any]) -> MBPushNotification? {
        let strategy = NotificationStrategyFactory.strategy(for: userInfo)
        return strategy.handle(userInfo: userInfo)
    }
}
