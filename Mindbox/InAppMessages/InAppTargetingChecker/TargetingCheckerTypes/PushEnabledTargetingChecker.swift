//
//  PushEnabledTargetingChecker.swift
//  Mindbox
//
//  Created by vailence on 27.03.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation

final class PushEnabledTargetingChecker: InternalTargetingChecker<PushEnabledTargeting> {
    override func checkInternal(targeting: PushEnabledTargeting) -> Bool {
        var pushPermissionBoolean = true
        switch SessionTemporaryStorage.shared.pushPermissionStatus {
            case .notDetermined, .denied:
                pushPermissionBoolean = false
            case .authorized, .provisional, .ephemeral:
                pushPermissionBoolean = true
            @unknown default:
                pushPermissionBoolean = true
        }
        
        return targeting.value == pushPermissionBoolean
    }
}
