//
//  MindboxPushNotification.swift
//  MindboxNotifications
//
//  Created by Sergei Semko on 8/15/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation

public protocol MindboxPushNotificationProtocol {
    func isMindboxPush(userInfo: [AnyHashable: Any]) -> Bool
    func getMindboxPushData(userInfo: [AnyHashable: Any]) -> MBPushNotification?
}

// MARK: - MindboxPushNotificationProtocol

extension MindboxNotificationService: MindboxPushNotificationProtocol {
    
    public func isMindboxPush(userInfo: [AnyHashable : Any]) -> Bool {
        return pushValidator?.isValid(item: userInfo) ?? false
    }
    
    public func getMindboxPushData(userInfo: [AnyHashable : Any]) -> MBPushNotification? {
        return NotificationFormatter.formatNotification(userInfo)
    }
}
