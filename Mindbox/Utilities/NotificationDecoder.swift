//
//  NotificationParser.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 31.03.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
import UserNotifications

struct NotificationDecoder<T: Codable> {
    
    var isMindboxNotification: Bool {
        userInfo[Constants.Notification.mindBoxIdentifireKey] != nil
    }
    
    private let userInfo: [AnyHashable: Any]
        
    init(request: UNNotificationRequest) throws {
        guard let userInfo = (request.content.mutableCopy() as? UNMutableNotificationContent)?.userInfo else {
            throw DeliveredNotificationManagerError.unableToFetchUserInfo
        }
        try self.init(userInfo: userInfo)
    }
    
    init(response: UNNotificationResponse) throws {
        try self.init(request: response.notification.request)
    }
    
    init(userInfo: [AnyHashable: Any]) throws {
        if userInfo.keys.count == 1, let innerUserInfo = userInfo["aps"] as? [AnyHashable: Any] {
            self.userInfo = innerUserInfo
        } else {
            self.userInfo = userInfo
        }
    }
    
    func decode() throws -> T {
        do {
            let data = try JSONSerialization.data(withJSONObject: userInfo, options: .prettyPrinted)
            let decoder = JSONDecoder()
            do {
                let payload = try decoder.decode(T.self, from: data)
                Log("Did parse payload: \(payload)")
                    .category(.notification).level(.info).make()
                return payload
            } catch {
                Log("Did fail to decode Payload with error: \(error.localizedDescription)")
                    .category(.notification).level(.error).make()
                throw error
            }
        } catch {
            Log("Did fail to serialize userInfo with error: \(error.localizedDescription)")
                .category(.notification).level(.error).make()
            throw error
        }
    }
    
}
