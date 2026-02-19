//
//  PushPermissionActionUseCase.swift
//  Mindbox
//
//  Created by vailence on 14.03.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger
import UserNotifications
import UIKit

extension ContentBackgroundLayerAction {
    /// Delegates to `ActionUseCaseFactory` to extract URL/payload and handle side effects.
    /// Returns `nil` for `.unknown` or empty redirect actions (no callback should be invoked).
    func handleTap() -> (url: URL?, payload: String)? {
        guard let useCase = ActionUseCaseFactory.createUseCase(action: self) else {
            return nil
        }
        return useCase.execute()
    }
}

final class PushPermissionActionUseCase: PresentationActionUseCaseProtocol {

    private let model: PushPermissionLayerAction

    init(model: PushPermissionLayerAction) {
        self.model = model
    }

    func execute() -> (url: URL?, payload: String)? {
        PushPermissionHelper.requestOrOpenSettings()
        return (nil, model.intentPayload)
    }
}

enum PushPermissionHelper {

    static func requestOrOpenSettings() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Logger.common(message: "Status of notification permission: \(settings.authorizationStatus.description)", level: .debug, category: .inAppMessages)
            switch settings.authorizationStatus {
            case .notDetermined:
                pushNotificationRequest()
            case .denied:
                openPushNotificationSettings()
            case .authorized, .provisional, .ephemeral:
                return
            @unknown default:
                Logger.common(message: "Encountered an unknown notification authorization status: \(settings.authorizationStatus.description)", level: .debug, category: .inAppMessages)
                return
            }
        }
    }

    private static func pushNotificationRequest() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                Logger.common(message: "Error requesting notification permissions: \(error)", level: .error, category: .inAppMessages)
                return
            }

            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                Logger.common(message: "Notification permission was granted by the user.", level: .debug, category: .inAppMessages)
            } else {
                Logger.common(message: "User did not grant notification permissions.", level: .debug, category: .inAppMessages)
            }
        }
    }

    private static func openPushNotificationSettings() {
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

            if UIApplication.shared.canOpenURL(settingsUrl) {
                UIApplication.shared.open(settingsUrl)
                Logger.common(message: "Navigated to app settings for notification permission.", level: .debug, category: .inAppMessages)
            }
        }
    }
}
