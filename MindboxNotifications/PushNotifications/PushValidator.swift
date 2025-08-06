//
//  Validator.swift
//  MindboxNotifications
//
//  Created by Sergei Semko on 8/15/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation

protocol PushValidator {
    func isValid(item: [AnyHashable: Any]) -> Bool
}

final class MindboxPushValidator: PushValidator {
    func isValid(item: [AnyHashable: Any]) -> Bool {
        guard NotificationFormatter.formatNotification(item) != nil else {
            return false
        }
        return true
    }
}
