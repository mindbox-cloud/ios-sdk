//
//  PushEnabledTargetingChecker.swift
//  Mindbox
//
//  Created by vailence on 27.03.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
import UserNotifications

final class PushEnabledTargetingChecker: InternalTargetingChecker<PushEnabledTargeting> {
    override func checkInternal(targeting: PushEnabledTargeting) -> Bool {
        let lock = DispatchSemaphore(value: 0)
        var isNotificationsEnabled = true

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
                case .notDetermined, .denied:
                    isNotificationsEnabled = false
                case .authorized, .provisional, .ephemeral:
                    isNotificationsEnabled = true
                @unknown default:
                    isNotificationsEnabled = true
            }
            lock.signal()
        }

        lock.wait()
        return targeting.value == isNotificationsEnabled
    }
}
