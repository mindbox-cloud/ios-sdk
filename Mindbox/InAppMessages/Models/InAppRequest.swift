//
//  InAppRequest.swift
//  Mindbox
//
//  Created by Максим Казаков on 06.09.2022.
//  Copyright © 2022 Mikhail Barilov. All rights reserved.
//

import Foundation

/// Contains data needed to request in-app messages that should be shown
struct InAppRequest {    
    let inAppId: String
    let triggerEvent: InAppMessageTriggerEvent
    let targeting: InAppRequestTargeting?
}

enum InAppRequestTargeting {
    case segment(segment: String, segmentation: String)
}
