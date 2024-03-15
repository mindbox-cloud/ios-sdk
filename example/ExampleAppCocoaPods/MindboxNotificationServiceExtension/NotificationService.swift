//
//  NotificationService.swift
//  MindboxNotificationServiceExtension
//
//  Created by Sergei Semko on 3/13/24.
//

import UserNotifications
import MindboxNotifications

// https://developers.mindbox.ru/docs/ios-send-rich-push-advanced#32-реализация-кода-расширения-в-приложении
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
