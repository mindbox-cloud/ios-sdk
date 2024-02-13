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
    
    typealias T = UNNotification
    
    func isValid(item: UNNotification) -> Bool {
        
        guard let pushModel = NotificationFormatter.formatNotification(item),
              pushModel.clickUrl != nil,
              let alert = pushModel.aps?.alert,
              alert.body != nil,
              alert.title != nil else {
            return false
        }
                
        return true
    }
}
