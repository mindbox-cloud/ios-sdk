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
        close()
    }
    
    func requestOrOpenSettingsForNotifications() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Logger.common(message: "Notification permission status: \(settings.authorizationStatus.description)", level: .debug, category: .inAppMessages)
            switch settings.authorizationStatus {
                case .notDetermined:
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                        if let error = error {
                            Logger.common(message: "Notification permission error: \(error)", level: .error, category: .inAppMessages)
                            return
                        }

                        if granted {
                            DispatchQueue.main.async {
                                UIApplication.shared.registerForRemoteNotifications()
                            }
                            Logger.common(message: "Notification permission granted", level: .debug, category: .inAppMessages)
                        } else {
                            Logger.common(message: "Notification permission not granted", level: .debug, category: .inAppMessages)
                        }
                    }
                case .denied:
                    DispatchQueue.main.async {
                        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(settingsUrl) else { return }
                        if UIApplication.shared.canOpenURL(settingsUrl) {
                            if #available(iOS 10.0, *) {
                                UIApplication.shared.open(settingsUrl, completionHandler: { (success) in

                                })
                            } else {
                                UIApplication.shared.openURL(settingsUrl)
                            }
                            
                            Logger.common(message: "Open app settings with notification permission", level: .debug, category: .inAppMessages)
                        }
                    }
                case .authorized, .provisional, .ephemeral:
                    return
                @unknown default:
                    Logger.common(message: "Caught unexpected new notification status. \(settings.authorizationStatus.description)", level: .debug, category: .inAppMessages)
                    return
            }
        }
    }
}
