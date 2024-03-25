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
        
        Logger.common(message: "NotificationDecoder: Successfully initialized NotificationDecoder. UserInfo \(userInfo)", level: .info, category: .notification)
        self.init(userInfo: userInfo)
    }
    
    init?(response: UNNotificationResponse) {
        self.init(request: response.notification.request)
    }
    
    init?(userInfo: [AnyHashable: Any]) {
        if userInfo.keys.count == 1, let innerUserInfo = userInfo["aps"] as? [AnyHashable: Any] {
            self.userInfo = innerUserInfo
        } else {
            self.userInfo = userInfo
        }
    }
    
    func decode() throws -> T {
        do {
            let data = try JSONSerialization.data(withJSONObject: userInfo, options: .prettyPrinted)
            Logger.common(message: "NotificationDecoder: Successfully serialized userInfo into data. data: \(data)", level: .info, category: .notification)
            let decoder = JSONDecoder()
            do {
                let payload = try decoder.decode(T.self, from: data)
                Logger.common(message: "NotificationDecoder: Successfully decoded data into payload. payload: \(payload)", level: .info, category: .notification)
                return payload
            } catch {
                Logger.common(message: "NotificationDecoder: Failed to decode data into payloadpayload. error: \(error)", level: .error, category: .notification)
                throw error
            }
        } catch {
            Logger.common(message: "NotificationDecoder: Failed to serialize userInfo into data. error: \(error)", level: .error, category: .general)
            throw error
        }
    }
}
