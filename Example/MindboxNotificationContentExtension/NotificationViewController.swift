//
//  NotificationViewController.swift
//  MindboxNotificationContentExtension
//
//  Created by Дмитрий Ерофеев on 31.03.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import UIKit
import UserNotifications
import UserNotificationsUI
import MindboxNotifications

class NotificationViewController: UIViewController, UNNotificationContentExtension {
    
    lazy var mindboxService = MindboxNotificationService()
    
    func didReceive(_ notification: UNNotification) {
        mindboxService.didReceive(notification: notification, viewController: self, extensionContext: extensionContext)
    }
}
