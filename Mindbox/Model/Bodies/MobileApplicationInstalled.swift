//
//  MobileApplicationInstalled.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 11.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

struct MobileApplicationInstalled: Codable {
    
    let token: String
    
    var isTokenAvailable: Bool
    
    let isNotificationsEnabled: Bool
    
    let installationId: String
    
    let subscribe: Bool
    
    let externalDeviceUUID: String?
    
    let version: Int
    
    let instanceId: String
    
    init(
        token: String? = nil,
        isNotificationsEnabled: Bool,
        installationId: String?,
        subscribe: Bool?,
        externalDeviceUUID: String?,
        version: Int,
        instanceId: String
    ) {
        self.token = token ?? ""
        self.isTokenAvailable = !self.token.isEmpty
        self.isNotificationsEnabled = isNotificationsEnabled
        self.installationId = installationId ?? ""
        self.subscribe = subscribe ?? false
        self.externalDeviceUUID = externalDeviceUUID
        self.version = version
        self.instanceId = instanceId
    }

}
