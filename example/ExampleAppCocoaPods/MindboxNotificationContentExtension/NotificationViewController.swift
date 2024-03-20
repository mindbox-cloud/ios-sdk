//
//  NotificationViewController.swift
//  MindboxNotificationContentExtension
//
//  Created by Sergei Semko on 3/13/24.
//

import UIKit
import UserNotifications
import UserNotificationsUI
import MindboxNotifications

// https://developers.mindbox.ru/docs/ios-send-rich-push-advanced#32-реализация-кода-расширения-в-приложении-1
final class NotificationViewController: UIViewController {
    
    lazy var mindboxService = MindboxNotificationService()
}

// MARK: - UNNotificationContentExtension

extension NotificationViewController: UNNotificationContentExtension {
    func didReceive(_ notification: UNNotification) {
        mindboxService.didReceive(
            notification: notification,
            viewController: self,
            extensionContext: extensionContext
        )
    }
}
