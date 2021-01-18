//
//  MobileApplicationInstalledRequest.swift
//  MindBox
//
//  Created by Mikhail Barilov on 18.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

class MobileApplicationInstalledRequest: RequestModel {
    init(endpoint: String, deviceUUID: String) {
        super.init(path: "String",
                   method: .post,
                   parameters: [:],
                   headers: [:],
                   body: [:]
        )
    }
}
