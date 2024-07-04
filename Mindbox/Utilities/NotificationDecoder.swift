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
        userInfo[Constants.Notification.mindBoxIdentifireKey] != nil
    }
    
    private let userInfo: [AnyHashable: Any]
        
    init(request: UNNotificationRequest) throws {
        guard let userInfo = (request.content.mutableCopy() as? UNMutableNotificationContent)?.userInfo else {
            let error = MindboxError.internalError(InternalError(errorKey: "unableToFetchUserInfo"))
            Logger.error(error.asLoggerError())
            throw error
        }
        try self.init(userInfo: userInfo)
    }
    
    init(response: UNNotificationResponse) throws {
        try self.init(request: response.notification.request)
    }
    
    init(userInfo: [AnyHashable: Any]) throws {
        if let jsonData = try? JSONSerialization.data(withJSONObject: userInfo, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            Logger.common(message: "NotificationDecoder JSON: \(jsonString)")
        } else {
            Logger.common(message: "NotificationDecoder: Unable to serialize userInfo to JSON", level: .error)
        }
        
        if let innerUserInfo = userInfo["aps"] as? [AnyHashable: Any], innerUserInfo["uniqueKey"] != nil {
            self.userInfo = innerUserInfo
            Logger.common(message: "Push Notification format with one big aps object")
        } else {
            self.userInfo = userInfo
            Logger.common(message: "Push Notification format with multiple keys")
        }
    }
    
    func decode() throws -> T {
        do {
            let data = try JSONSerialization.data(withJSONObject: userInfo, options: .prettyPrinted)
            let decoder = JSONDecoder()
            do {
                let payload = try decoder.decode(T.self, from: data)
                Logger.common(message: "Did parse payload: \(payload)", level: .info, category: .notification)
                return payload
            } catch {
                Logger.common(message: "Did fail to decode Payload with error: \(error.localizedDescription)", level: .info, category: .notification)
                throw error
            }
        } catch {
            Logger.common(message: "Did fail to serialize userInfo with error: \(error.localizedDescription)", level: .info, category: .notification)
            throw error
        }
    }
    
}
