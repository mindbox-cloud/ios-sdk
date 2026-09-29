//
//  MBPushNotification.swift
//  Mindbox
//
//  Created by vailence on 09.02.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation

public struct MBPushNotification: Codable, Sendable {
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

public struct MBAps: Codable, Sendable {
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

public struct MBApsAlert: Codable, Sendable {
    public let title: String?
    public let body: String?
}

public struct MBPushNotificationButton: Codable, Sendable {
    public let text: String?
    public let url: String?
    public let uniqueKey: String?
}
