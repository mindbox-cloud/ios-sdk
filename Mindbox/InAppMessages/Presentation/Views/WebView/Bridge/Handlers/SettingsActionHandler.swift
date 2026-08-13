//
//  SettingsActionHandler.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit
import MindboxLogger

/// Sends the user to the system settings the page asked for.
///
/// Notification settings have their own route, because on newer systems they open the app's
/// notification screen directly rather than its top-level page.
final class SettingsActionHandler: WebBridgeActionHandler {

    let actions: Set<BridgeMessage.Action> = [.settingsOpen]

    private let urlOpener: BridgeURLOpening
    private let openNotificationSettings: (@escaping (Bool) -> Void) -> Void

    init(urlOpener: BridgeURLOpening = SystemURLOpener(),
         openNotificationSettings: @escaping (@escaping (Bool) -> Void) -> Void
         = { PushPermissionHelper.openPushNotificationSettings(completion: $0) }) {
        self.urlOpener = urlOpener
        self.openNotificationSettings = openNotificationSettings
    }

    func handle(_ message: BridgeMessage, host: WebBridgeHost) {
        guard let target = SettingsRequestParser.parse(from: message) else {
            host.respondError("Invalid or unknown settings type", to: message)
            return
        }

        Logger.common(message: "[WebView] openSettings: type='\(target.rawValue)'",
                      level: .info,
                      category: host.logCategory)

        switch target {
        case .notifications:
            // The outcome is not inspected: the page asked to be sent to settings, and it was.
            openNotificationSettings { _ in
                DispatchQueue.main.async {
                    host.respondSuccess(to: message)
                }
            }
        case .application:
            guard let url = URL(string: UIApplication.openSettingsURLString) else {
                host.respondError("Failed to create application settings URL", to: message)
                return
            }

            urlOpener.open(url, answering: message, host: host)
        }
    }
}
