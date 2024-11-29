//
//  NotificationService.swift
//  MindboxNotificationServiceExtension
//
//  Created by Дмитрий Ерофеев on 30.03.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import UserNotifications
import MindboxNotifications

class NotificationService: UNNotificationServiceExtension {
    
    lazy var mindboxService = MindboxNotificationService()
    
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        mindboxService.didReceive(request, withContentHandler: contentHandler)
    }
    
    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
        mindboxService.serviceExtensionTimeWillExpire()
    }
}
