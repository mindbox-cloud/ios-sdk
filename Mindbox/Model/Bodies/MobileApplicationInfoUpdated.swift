//
//  MobileApplicationInfoUpdated.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 11.02.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation

struct MobileApplicationInfoUpdated: Codable {

    let isNotificationsEnabled: Bool

    let version: Int

    let instanceId: String

    let tokens: [TokenData]

    init(token: String?,
         isNotificationsEnabled: Bool,
         version: Int,
         instanceId: String,
         notificationProvider: String = "APNS") {

        if let tokenValue = token, !tokenValue.isEmpty {
            let tokenData = TokenData(token: tokenValue, notificationProvider: notificationProvider)
            self.tokens = [tokenData]
        } else {
            self.tokens = []
        }

        self.isNotificationsEnabled = isNotificationsEnabled
        self.version = version
        self.instanceId = instanceId
    }
}
