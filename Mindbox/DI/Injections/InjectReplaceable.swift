//
//  InjectReplaceable.swift
//  Mindbox
//
//  Created by vailence on 21.06.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
import UIKit

extension MBContainer {
    func registerReplaceableUtilities() -> Self {
        register(UUIDDebugService.self) {
            PasteboardUUIDDebugService(
                notificationCenter: NotificationCenter.default,
                currentDateProvider: { return Date() },
                pasteboard: UIPasteboard.general
            )
        }
        
        register(UNAuthorizationStatusProviding.self, scope: .transient) {
            UNAuthorizationStatusProvider()
        }
        
        register(SDKVersionValidator.self) {
            SDKVersionValidator(sdkVersionNumeric: Constants.Versions.sdkVersionNumeric)
        }
        
        return self
    }
}
