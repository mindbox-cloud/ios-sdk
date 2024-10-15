//
//  MobileApplicationInfoUpdated.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 11.02.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation

struct MobileApplicationInfoUpdated: Codable {

    let notificationProvider: String

    let token: String

    var isTokenAvailable: Bool

    let isNotificationsEnabled: Bool

    let version: Int

    let instanceId: String

    init(token: String?,
         isNotificationsEnabled: Bool,
         version: Int,
         instanceId: String,
         notificationProvider: String = "APNS") {
        self.token = token ?? ""
        self.isTokenAvailable = !self.token.isEmpty
        self.isNotificationsEnabled = isNotificationsEnabled
        self.version = version
        self.instanceId = instanceId
        self.notificationProvider = notificationProvider
    }
}
