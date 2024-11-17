//
//  LocalPushNotificationModel.swift
//  MindboxNotificationServiceExtension
//
//  Created by Sergei Semko on 11/14/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
import MindboxNotifications

public struct MBLocalPushNotification: Codable {
    public var pushData: MBPushNotification
    public var showTimeGTM: String

    enum CodingKeys: String, CodingKey {
        case showTimeGTM
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        showTimeGTM = try container.decode(String.self, forKey: .showTimeGTM)

        let pushDataDecoder = try decoder.singleValueContainer()
        pushData = try pushDataDecoder.decode(MBPushNotification.self)
    }

    static func decode(from data: Data) -> Self? {
        return try? JSONDecoder().decode(Self.self, from: data)
    }
}

