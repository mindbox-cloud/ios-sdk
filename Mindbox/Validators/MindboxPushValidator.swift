//
//  MindboxPushValidator.swift
//  Mindbox
//
//  Created by vailence on 09.02.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
import UserNotifications
import MindboxLogger

class MindboxPushValidator: Validator {
    
    typealias T = [AnyHashable: Any]
    
    func isValid(item: [AnyHashable : Any]) -> Bool {
        guard let pushModel = NotificationFormatter.formatNotification(item) else {
            Logger.common(message: "MindboxPushValidator. Cannot convert to Mindbox push model. Return false", level: .error, category: .notification)
            return false
        }
                
        return true
    }
}
