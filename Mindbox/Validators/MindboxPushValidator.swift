//
//  MindboxPushValidator.swift
//  Mindbox
//
//  Created by vailence on 09.02.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
import UserNotifications

class MindboxPushValidator: Validator {
    
    typealias T = [AnyHashable: Any]
    
    func isValid(item: [AnyHashable : Any]) -> Bool {
        guard let pushModel = NotificationFormatter.formatNotification(item),
              let clickUrl = pushModel.clickUrl,
              let alert = pushModel.aps?.alert,
              let body = alert.body,
              let title = alert.title else {
            return false
        }
                
        return true
    }
}
