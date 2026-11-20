//
//  MindboxNotificationService.swift
//  Mindbox
//
//  Created by Ihor Kandaurov on 26.04.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import UIKit
import UserNotifications
import UserNotificationsUI

@objcMembers
public class MindboxNotificationService: NSObject {

    // MARK: MindboxNotificationServiceProtocol

    public var contentHandler: ((UNNotificationContent) -> Void)?
    public var bestAttemptContent: UNMutableNotificationContent?

    // MARK: Internal properties

    var context: NSExtensionContext?
    var viewController: UIViewController?

    var pushValidator: PushValidator?
    lazy var deliveryConfirmer = PushDeliveryConfirmer()

    // MARK: Public initializer

    /// Mindbox proxy for `NotificationsService` and `NotificationViewController`
    override public init() {
        super.init()
        pushValidator = MindboxPushValidator()
    }
}
