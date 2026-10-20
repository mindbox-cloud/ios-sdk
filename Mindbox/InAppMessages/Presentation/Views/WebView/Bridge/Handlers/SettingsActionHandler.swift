//
//  SettingsActionHandler.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit
import MindboxLogger

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
        guard let requested = SettingsRequestParser.target(from: message) else {
            host.respondError(.invalidPayload, detail: "missing or empty 'target' field", to: message)
            return
        }

        guard let target = SettingsType(rawValue: requested) else {
            host.respondError(.unsupportedValue, detail: "unknown settings target '\(requested)'", to: message)
            return
        }

        Logger.common(message: "[WebView] openSettings: type='\(target.rawValue)'",
                      level: .info,
                      category: host.logCategory)

        switch target {
        case .notifications:
            openNotificationSettings { [weak host] _ in
                DispatchQueue.main.async {
                    guard let host else { return }

                    host.respondSuccess(to: message)
                }
            }
        case .application:
            guard let url = URL(string: UIApplication.openSettingsURLString) else {
                host.respondError(.openFailed, detail: "could not build the application settings URL", to: message)
                return
            }

            urlOpener.open(url, answering: message, host: host)
        }
    }
}
