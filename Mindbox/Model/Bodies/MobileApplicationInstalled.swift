//
//  MobileApplicationInstalled.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 11.02.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation

struct MobileApplicationInstalled: Codable {

    let isNotificationsEnabled: Bool

    let installationId: String

    let subscribe: Bool

    let externalDeviceUUID: String?

    let version: Int

    let instanceId: String

    /// ID текущая таймзона устройства в формате IANA, например "Asia/Krasnoyarsk", null если недоступно
    let ianaTimeZone: String?

    let tokens: [TokenData]

    init(
        token: String? = nil,
        isNotificationsEnabled: Bool,
        installationId: String?,
        subscribe: Bool?,
        externalDeviceUUID: String?,
        version: Int,
        instanceId: String,
        notificationProvider: String = "APNS",
        ianaTimeZone: String?
    ) {
        if let tokenValue = token, !tokenValue.isEmpty {
            let tokenData = TokenData(token: tokenValue, notificationProvider: notificationProvider)
            self.tokens = [tokenData]
        } else {
            self.tokens = []
        }

        self.isNotificationsEnabled = isNotificationsEnabled
        self.installationId = installationId ?? ""
        self.subscribe = subscribe ?? false
        self.externalDeviceUUID = externalDeviceUUID
        self.version = version
        self.instanceId = instanceId
        self.ianaTimeZone = ianaTimeZone
    }
}
