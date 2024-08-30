//
//  NotificationFormatStrategy.swift
//  MindboxNotifications
//
//  Created by Sergei Semko on 8/15/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

protocol NotificationFormatStrategy {
    func handle(userInfo: [AnyHashable: Any]) -> MBPushNotification?
}

final class LegacyFormatStrategy: NotificationFormatStrategy {
    func handle(userInfo: [AnyHashable: Any]) -> MBPushNotification? {
        guard let apsData = userInfo["aps"] as? [String: Any],
              let alertData = apsData["alert"] as? [String: Any],
              let body = alertData["body"] as? String,
              let clickUrl = apsData["clickUrl"] as? String else {
            Logger.common(message: "LegacyFormatStrategy: Failed to parse legacy notification format. userInfo: \(userInfo)", level: .error, category: .notification)
            return nil
        }
    
        let title = alertData["title"] as? String
        let sound = apsData["sound"] as? String
        let mutableContent = apsData["mutable-content"] as? Int
        let contentAvailable = apsData["content-available"] as? Int
        
        let buttons = (apsData["buttons"] as? [[String: Any]])?.compactMap { dict -> MBPushNotificationButton? in
            guard let text = dict["text"] as? String,
                  let url = dict["url"] as? String,
                  let uniqueKey = dict["uniqueKey"] as? String else {
                Logger.common(message: "LegacyFormatStrategy: Error parsing button data. dictionary: \(dict)", level: .error, category: .notification)
                return nil
            }
            return MBPushNotificationButton(text: text, url: url, uniqueKey: uniqueKey)
        }
        
        Logger.common(message: "LegacyFormatStrategy: Successfully parsed legacy notification format.", level: .info, category: .notification)
        return MBPushNotification(
            aps: MBAps(alert: MBApsAlert(title: title, body: body),
                       sound: sound,
                       mutableContent: mutableContent,
                       contentAvailable: contentAvailable),
            clickUrl: clickUrl,
            imageUrl: apsData["imageUrl"] as? String,
            payload: apsData["payload"] as? String,
            buttons: buttons,
            uniqueKey: apsData["uniqueKey"] as? String
        )
    }
}

final class CurrentFormatStrategy: NotificationFormatStrategy {
    func handle(userInfo: [AnyHashable : Any]) -> MBPushNotification? {
        guard let data = try? JSONSerialization.data(withJSONObject: userInfo),
              let notificationModel = try? JSONDecoder().decode(MBPushNotification.self, from: data),
              let clickUrl = notificationModel.clickUrl,
              let alert = notificationModel.aps?.alert,
              let body = alert.body else {
            Logger.common(message: "CurrentFormatStrategy: Failed to parse current notification format. userInfo: \(userInfo)", level: .error, category: .notification)
            return nil
        }
        
        Logger.common(message: "CurrentFormatStrategy: Successfully parsed current notification format.", level: .info, category: .notification)
        return notificationModel
    }
}
