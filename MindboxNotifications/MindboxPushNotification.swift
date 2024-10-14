//
//  MindboxPushNotification.swift
//  MindboxNotifications
//
//  Created by Sergei Semko on 8/15/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

public protocol MindboxPushNotificationProtocol {
    func isMindboxPush(userInfo: [AnyHashable: Any]) -> Bool
    func getMindboxPushData(userInfo: [AnyHashable: Any]) -> MBPushNotification?
}

// MARK: - MindboxPushNotificationProtocol

extension MindboxNotificationService: MindboxPushNotificationProtocol {
    
    public func isMindboxPush(userInfo: [AnyHashable: Any]) -> Bool {
        let message = "[NotificationService]: \(#function)"
        Logger.common(message: message, level: .info, category: .notification)
        return pushValidator?.isValid(item: userInfo) ?? false
    }
    
    public func getMindboxPushData(userInfo: [AnyHashable: Any]) -> MBPushNotification? {
        let message = "[NotificationService]: \(#function)"
        Logger.common(message: message, level: .info, category: .notification)
        return NotificationFormatter.formatNotification(userInfo)
    }
}
