//
//  InAppsCheckRequest.swift
//  Mindbox
//
//  Created by Максим Казаков on 06.09.2022.
//  Copyright © 2022 Mikhail Barilov. All rights reserved.
//

import Foundation

/// Contains data needed to request in-app messages that should be shown
struct InAppsCheckRequest {
    let triggerEvent: InAppMessageTriggerEvent

    let possibleInApps: [InAppInfo]

    struct InAppInfo {
        let inAppId: String
        let targetings: [InAppRequestTargeting]
    }
}

enum InAppRequestTargeting {
    case segment(segmentation: String, segment: String)
}
