//
//  PushPermissionHelper.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 19.03.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import UIKit
import MindboxLogger

enum PushPermissionHelper {

    static func requestPermission(completion: ((PermissionRequestResult) -> Void)? = nil) {
        let registry = DI.injectOrFail(PermissionHandlerRegistryProtocol.self)
        registry.handler(for: .pushNotifications)?.request { result in
            completion?(result)
        }
    }

    static func openPushNotificationSettings() {
        DispatchQueue.main.async {
            let settingsUrl: URL?
            if #available(iOS 16.0, *) {
                settingsUrl = URL(string: UIApplication.openNotificationSettingsURLString)
            } else {
                settingsUrl = URL(string: UIApplication.openSettingsURLString)
            }
            guard let settingsUrl = settingsUrl, UIApplication.shared.canOpenURL(settingsUrl) else {
                Logger.common(message: "Failed to parse the settings URL or encountered an issue opening it.", level: .debug, category: .inAppMessages)
                return
            }
            UIApplication.shared.open(settingsUrl)
            Logger.common(message: "Navigated to app settings for notification permission.", level: .debug, category: .inAppMessages)
        }
    }
}
