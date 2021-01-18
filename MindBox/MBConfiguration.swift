//
//  MBConfiguration.swift
//  MindBox
//
//  Created by Mikhail Barilov on 13.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

public struct MBConfiguration {
    public let endpoint: String
    public let domain: String
    public var installationId: String?
    public var deviceUUID: String?

    public init(
        endpoint: String,
        domain: String,
        installationId: String? = nil,
        deviceUUID: String? = nil
    ) {
        self.endpoint = endpoint
        self.domain = domain
        self.installationId = installationId
        self.deviceUUID = deviceUUID
    }

    init?(configName: String) {
        let config = MBConfiguration(endpoint: "", domain: "")
        return nil
    }
}
