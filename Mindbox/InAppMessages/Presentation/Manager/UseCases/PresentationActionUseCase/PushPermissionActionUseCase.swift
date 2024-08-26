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

final class PushPermissionActionUseCase: PresentationActionUseCaseProtocol {
    
    private let tracker: PresentationClickTracker
    private let model: PushPermissionLayerAction
    
    init(tracker: PresentationClickTracker, model: PushPermissionLayerAction) {
        self.tracker = tracker
        self.model = model
    }
    
    func onTapAction(
        id: String,
        onTap: @escaping InAppMessageTapAction,
        close: @escaping () -> Void
    ) {
        tracker.trackClick(id: id)
        Logger.common(message: "In-app with push permission | ID: \(id)", level: .debug, category: .inAppMessages)
        requestOrOpenSettingsForNotifications()
        onTap(nil, model.intentPayload)
        close()
    }
    
    func requestOrOpenSettingsForNotifications() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Logger.common(message: "Status of notification permission: \(settings.authorizationStatus.description)", level: .debug, category: .inAppMessages)
            switch settings.authorizationStatus {
                case .notDetermined:
                    self.pushNotificationRequest()
                case .denied:
                    self.openPushNotificationSettings()
                case .authorized, .provisional, .ephemeral:
                    return
                @unknown default:
                    Logger.common(message: "Encountered an unknown notification authorization status: \(settings.authorizationStatus.description)", level: .debug, category: .inAppMessages)
                    return
            }
        }
    }
    
    private func pushNotificationRequest() {
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
    
    private func openPushNotificationSettings() {
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
