//
//  NotificationParser.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 31.03.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation
import UserNotifications
import MindboxLogger

struct NotificationDecoder<T: Codable> {
    var isMindboxNotification: Bool {
        userInfo["uniqueKey"] != nil
    }

    private let userInfo: [AnyHashable: Any]

    init?(request: UNNotificationRequest) {
        guard let userInfo = (request.content.mutableCopy() as? UNMutableNotificationContent)?.userInfo else {
            Logger.common(message: "NotificationDecoder: Failed to get user info from notification content", level: .fault, category: .notification)
            return nil
        }
        
        self.init(userInfo: userInfo)
    }
    
    init?(response: UNNotificationResponse) {
        self.init(request: response.notification.request)
    }
    
    init?(userInfo: [AnyHashable: Any]) {
        if let innerUserInfo = userInfo["aps"] as? [AnyHashable: Any], innerUserInfo["uniqueKey"] != nil {
            self.userInfo = innerUserInfo
            Logger.common(message: "Old Push Notification format with one big aps object")
        } else {
            self.userInfo = userInfo
            Logger.common(message: "New Push Notification format with multiple keys")
        }
    }
    
    func decode() throws -> T {
        do {
            let data = try JSONSerialization.data(withJSONObject: userInfo, options: .prettyPrinted)
            let decoder = JSONDecoder()
            do {
                let payload = try decoder.decode(T.self, from: data)
                return payload
            } catch {
                Logger.common(message: "NotificationDecoder: Failed to decode data into payload. error: \(error)", level: .error, category: .notification)
                throw error
            }
        } catch {
            Logger.common(message: "NotificationDecoder: Failed to serialize userInfo into data. error: \(error)", level: .error, category: .notification)
            throw error
        }
    }
}
