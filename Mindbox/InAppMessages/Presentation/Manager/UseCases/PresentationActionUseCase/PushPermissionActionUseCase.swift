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
        requestOrOpenSettingsForNotifications { settingsUrl in
            onTap(settingsUrl, self.model.intentPayload)
        }
        close()
    }
    
    func requestOrOpenSettingsForNotifications(_ completion: @escaping (URL?) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Logger.common(message: "Status of notification permission: \(settings.authorizationStatus.description)", level: .debug, category: .inAppMessages)
            switch settings.authorizationStatus {
                case .notDetermined:
                    completion(nil)
                    self.pushNotificationRequest()
                case .denied:
                    self.getPushNotificationSettingsUrl { url in
                        completion(url)
                    }
                case .authorized, .provisional, .ephemeral:
                    completion(nil)
                @unknown default:
                    completion(nil)
                    Logger.common(message: "Encountered an unknown notification authorization status: \(settings.authorizationStatus.description)", level: .debug, category: .inAppMessages)
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
    
    private func getPushNotificationSettingsUrl(_ completion: @escaping (URL?) -> Void) {
        DispatchQueue.main.async {
            let settingsUrl: URL?
            if #available(iOS 16.0, *) {
                settingsUrl = URL(string: UIApplication.openNotificationSettingsURLString)
            } else {
                settingsUrl = URL(string: UIApplication.openSettingsURLString)
            }
            
            if let settingsUrl, UIApplication.shared.canOpenURL(settingsUrl) {
                completion(settingsUrl)
            } else {
                Logger.common(message: "Failed to parse the settings URL or encountered an issue opening it.", level: .debug, category: .inAppMessages)
                completion(nil)
            }
        }
    }
}
