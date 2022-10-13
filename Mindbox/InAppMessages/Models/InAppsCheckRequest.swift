//
//  InAppsCheckRequest.swift
//  Mindbox
//
//  Created by Максим Казаков on 06.09.2022.
//  Copyright © 2022 Mikhail Barilov. All rights reserved.
//

import Foundation

/// Contains data needed to request in-app messages that should be shown
struct InAppsCheckRequest: Equatable {
    let triggerEvent: InAppMessageTriggerEvent
    var possibleInApps: [InAppInfo]

    struct InAppInfo: Equatable {
        let inAppId: String
        let targeting: SegmentationTargeting?
    }
}
