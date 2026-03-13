//
//  PushNotificationsPermissionHandler.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 13.03.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import UserNotifications
import UIKit
import MindboxLogger

final class PushNotificationsPermissionHandler: PermissionHandler {

    let permissionType: PermissionType = .pushNotifications
    let requiredInfoPlistKeys: [String] = []

    func request(completion: @escaping (PermissionRequestResult) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Logger.common(
                message: "Push permission status: \(settings.authorizationStatus.description)",
                level: .debug,
                category: .inAppMessages
            )

            switch settings.authorizationStatus {
            case .notDetermined:
                self.requestAuthorization(completion: completion)
            case .denied:
                self.openSettings()
                completion(.denied)
            case .authorized, .provisional, .ephemeral:
                completion(.granted)
            @unknown default:
                completion(.error("Unknown authorization status"))
            }
        }
    }

    private func requestAuthorization(completion: @escaping (PermissionRequestResult) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                Logger.common(
                    message: "Error requesting notification permissions: \(error)",
                    level: .error,
                    category: .inAppMessages
                )
                completion(.error(error.localizedDescription))
                return
            }

            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                Logger.common(
                    message: "Notification permission was granted by the user.",
                    level: .debug,
                    category: .inAppMessages
                )
                completion(.granted)
            } else {
                Logger.common(
                    message: "User did not grant notification permissions.",
                    level: .debug,
                    category: .inAppMessages
                )
                completion(.denied)
            }
        }
    }

    private func openSettings() {
        DispatchQueue.main.async {
            let settingsUrl: URL?
            if #available(iOS 16.0, *) {
                settingsUrl = URL(string: UIApplication.openNotificationSettingsURLString)
            } else {
                settingsUrl = URL(string: UIApplication.openSettingsURLString)
            }

            guard let settingsUrl, UIApplication.shared.canOpenURL(settingsUrl) else {
                Logger.common(
                    message: "Failed to parse the settings URL or encountered an issue opening it.",
                    level: .debug,
                    category: .inAppMessages
                )
                return
            }

            UIApplication.shared.open(settingsUrl)
            Logger.common(
                message: "Navigated to app settings for notification permission.",
                level: .debug,
                category: .inAppMessages
            )
        }
    }
}
