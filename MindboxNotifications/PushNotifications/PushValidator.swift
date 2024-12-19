//
//  Validator.swift
//  MindboxNotifications
//
//  Created by Sergei Semko on 8/15/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

protocol PushValidator {
    func isValid(item: [AnyHashable: Any]) -> Bool
}

final class MindboxPushValidator: PushValidator {
    func isValid(item: [AnyHashable: Any]) -> Bool {
        guard NotificationFormatter.formatNotification(item) != nil else {
            Logger.common(message: "[NotificationServiceChecker] MindboxPushValidator: Failed to convert item to Mindbox push model. Validation failed.", level: .error, category: .notification)
            return false
        }

        Logger.common(message: "[NotificationServiceChecker] MindboxPushValidator: Successfully validated Mindbox push model.", level: .info, category: .notification)
        return true
    }
}
