//
//  PushDeliveryConfirmationSignal.swift
//  MindboxNotifications
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

enum PushDeliveryConfirmationSignal {

    static func name(hostBundleIdentifier: String) -> String {
        "cloud.Mindbox.pushDeliveryConfirmation.\(hostBundleIdentifier)"
    }

    static func post(hostBundle: Bundle = PushDeliveryConfirmationHeaders.hostApplicationBundle()) {
        guard let bundleIdentifier = hostBundle.bundleIdentifier else {
            return
        }
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(name(hostBundleIdentifier: bundleIdentifier) as CFString),
            nil,
            nil,
            true
        )
    }
}
