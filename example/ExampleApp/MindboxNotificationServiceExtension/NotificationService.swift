//
//  NotificationService.swift
//  MindboxNotificationServiceExtension
//
//  Created by Sergei Semko on 3/13/24.
//

import UserNotifications
import MindboxNotifications

final class NotificationService: UNNotificationServiceExtension {

    lazy var mindboxService = MindboxNotificationService()

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        mindboxService.didReceive(request, withContentHandler: contentHandler)
    }
    
    override func serviceExtensionTimeWillExpire() {
        mindboxService.serviceExtensionTimeWillExpire()
    }

}
