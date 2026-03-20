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
                message: "[WebView] Push notification permission status: \(settings.authorizationStatus.description)",
                level: .debug,
                category: .webViewInAppMessages
            )

            switch settings.authorizationStatus {
            case .notDetermined:
                self.requestAuthorization(completion: completion)
            case .denied:
                completion(.denied(dialogShown: false))
            case .authorized, .provisional, .ephemeral:
                completion(.granted(dialogShown: false))
            @unknown default:
                completion(.error("Unknown authorization status"))
            }
        }
    }

    private func requestAuthorization(completion: @escaping (PermissionRequestResult) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                Logger.common(
                    message: "[WebView] Error requesting notification permissions: \(error)",
                    level: .error,
                    category: .webViewInAppMessages
                )
                completion(.error(error.localizedDescription))
                return
            }

            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                Logger.common(
                    message: "[WebView] Notification permission was granted by the user.",
                    level: .debug,
                    category: .webViewInAppMessages
                )
                completion(.granted(dialogShown: true))
            } else {
                Logger.common(
                    message: "[WebView] User did not grant notification permissions.",
                    level: .debug,
                    category: .webViewInAppMessages
                )
                completion(.denied(dialogShown: true))
            }
        }
    }
}
