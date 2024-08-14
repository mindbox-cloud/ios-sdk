//
//  MindboxNotificationService.swift
//  Mindbox
//
//  Created by Ihor Kandaurov on 26.04.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import UIKit
import MindboxLogger
import UserNotifications
import UserNotificationsUI

@objcMembers
public class MindboxNotificationService: NSObject {
    
    // MARK: MindboxNotificationServiceProtocol
    
    public var contentHandler: ((UNNotificationContent) -> Void)?
    public var bestAttemptContent: UNMutableNotificationContent?

    // MARK:  Internal properties
    
    var context: NSExtensionContext?
    var viewController: UIViewController?

    // MARK: Public initializer
    
    /// Mindbox proxy for `NotificationsService` and `NotificationViewController`
    public override init() {
        super.init()
    }
}
