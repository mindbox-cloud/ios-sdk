//
//  SharedInternalMethods.swift
//  MindboxNotifications
//
//  Created by Sergei Semko on 8/12/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import UIKit
import MindboxLogger

// MARK: - Shared internal methods

extension MindboxNotificationService {
    func parse(request: UNNotificationRequest) -> Payload? {
        guard let userInfo = getUserInfo(from: request) else {
            Logger.common(message: "MindboxNotificationService: Failed to get userInfo", level: .error, category: .notification)
            return nil
        }
        guard let data = try? JSONSerialization.data(withJSONObject: userInfo, options: .prettyPrinted) else {
            Logger.common(message: "MindboxNotificationService: Failed to get data. userInfo: \(userInfo)", level: .error, category: .notification)
            return nil
        }

        var payload = Payload()

        payload.withButton = try? JSONDecoder().decode(Payload.Button.self, from: data)
        Logger.common(message: "MindboxNotificationService: payload.withButton: \(String(describing: payload.withButton))", level: .info, category: .notification)
        
        payload.withImageURL = try? JSONDecoder().decode(Payload.ImageURL.self, from: data)
        Logger.common(message: "MindboxNotificationService: payload.withImageURL: \(String(describing: payload.withImageURL))", level: .info, category: .notification)
        
        return payload
    }
    
    func getUserInfo(from request: UNNotificationRequest) -> [AnyHashable: Any]? {
        guard let userInfo = (request.content.mutableCopy() as? UNMutableNotificationContent)?.userInfo else {
            Logger.common(message: "MindboxNotificationService: Failed to get userInfo", level: .error, category: .notification)
            return nil
        }
        
        if let innerUserInfo = userInfo["aps"] as? [AnyHashable: Any], innerUserInfo["uniqueKey"] != nil {
            Logger.common(message: "MindboxNotificationService: userInfo: \(innerUserInfo), userInfo.keys.count: \(userInfo.keys.count), innerUserInfo: \(innerUserInfo)", level: .info, category: .notification)
            return innerUserInfo
        } else {
            Logger.common(message: "MindboxNotificationService: userInfo: \(userInfo)", level: .info, category: .notification)
            return userInfo
        }
    }
}
