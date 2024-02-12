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
    let aps: MBAps?
    let clickUrl: String?
    let imageUrl: String?
    let payload: String?
    let buttons: [MBPushNotificationButton]?
    let uniqueKey: String?

    enum CodingKeys: String, CodingKey {
        case aps, clickUrl, imageUrl, payload, buttons, uniqueKey
    }
}

// Структура для APS секции
public struct MBAps: Codable {
    let alert: MBApsAlert?
    let sound: String?
    let mutableContent: Int?
    let contentAvailable: Int?

    enum CodingKeys: String, CodingKey {
        case alert, sound
        case mutableContent = "mutable-content"
        case contentAvailable = "content-available"
    }
}

// Структура для alert секции
public struct MBApsAlert: Codable {
    let title: String?
    let body: String?
}

// Структура для кнопок
public struct MBPushNotificationButton: Codable {
    let text: String?
    let url: String?
    let uniqueKey: String?
}
