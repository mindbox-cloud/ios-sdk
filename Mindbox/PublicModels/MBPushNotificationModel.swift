//
//  MBPushNotificationModel.swift
//  Mindbox
//
//  Created by vailence on 09.02.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation

// Основная структура для пуш-уведомления
public struct MBPushNotification: Codable {
    public let aps: MBAps?
    public let clickUrl: String?
    public let imageUrl: String?
    public let payload: String?
    public let buttons: [MBPushNotificationButton]?
    public let uniqueKey: String?

    enum CodingKeys: String, CodingKey {
        case aps, clickUrl, imageUrl, payload, buttons, uniqueKey
    }
}

// Структура для APS секции
public struct MBAps: Codable {
    public let alert: MBApsAlert?
    public let sound: String?
    public let mutableContent: Int?
    public let contentAvailable: Int?

    enum CodingKeys: String, CodingKey {
        case alert, sound
        case mutableContent = "mutable-content"
        case contentAvailable = "content-available"
    }
}

// Структура для alert секции
public struct MBApsAlert: Codable {
    public let title: String?
    public let body: String?
}

// Структура для кнопок
public struct MBPushNotificationButton: Codable {
    public let text: String?
    public let url: String?
    public let uniqueKey: String?
}
