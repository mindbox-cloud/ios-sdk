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
        guard let pushData = item.request.content.userInfo as? [String: AnyObject] else {
            return false
        }
        
        do {
            let data = try JSONSerialization.data(withJSONObject: pushData, options: [])
            let decoder = JSONDecoder()
            let pushNotification = try decoder.decode(MBPushNotification.self, from: data)
            
            guard pushNotification.clickUrl != nil,
                  let alert = pushNotification.aps?.alert,
                  alert.body != nil,
                  alert.title != nil else {
                return false
            }
            
            return true
        } catch {
            return false
        }
    }
}
