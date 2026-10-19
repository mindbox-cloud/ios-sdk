//
//  WebBridgeActionHandlerFactory.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

enum WebBridgeActionHandlerFactory {

    static func makeHandlers() -> [WebBridgeActionHandler] {
        [
            ReadyActionHandler(),
            LogActionHandler(),
            LocalStateActionHandler(),
            OpenLinkActionHandler(),
            SettingsActionHandler(),
            PermissionActionHandler(),
            HapticActionHandler(),
            MotionActionHandler(),
            OperationActionHandler(),
            LifecycleActionHandler(),
            ContentRenderedActionHandler(),
            FilterShowableInappsActionHandler(),
            ShowInAppActionHandler()
        ]
    }
}
