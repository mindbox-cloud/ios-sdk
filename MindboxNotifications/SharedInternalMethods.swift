//
//  SharedInternalMethods.swift
//  MindboxNotifications
//
//  Created by Sergei Semko on 8/12/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import UIKit

// MARK: - Shared internal methods

extension MindboxNotificationService {
    func parse(request: UNNotificationRequest) -> Payload? {
        guard let userInfo = getUserInfo(from: request) else {
            return nil
        }
        guard let data = try? JSONSerialization.data(withJSONObject: userInfo, options: .prettyPrinted) else {
            return nil
        }

        var payload = Payload()
        payload.withButton = try? JSONDecoder().decode(Payload.Button.self, from: data)
        payload.withImageURL = try? JSONDecoder().decode(Payload.ImageURL.self, from: data)

        return payload
    }

    func getUserInfo(from request: UNNotificationRequest) -> [AnyHashable: Any]? {
        guard let userInfo = (request.content.mutableCopy() as? UNMutableNotificationContent)?.userInfo else {
            return nil
        }

        if let innerUserInfo = userInfo["aps"] as? [AnyHashable: Any], innerUserInfo["uniqueKey"] != nil {
            return innerUserInfo
        } else {
            return userInfo
        }
    }
}
