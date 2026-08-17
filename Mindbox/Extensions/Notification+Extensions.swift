//
//  Notification+Extensions.swift
//  Mindbox
//
//  Created by Sergei Semko on 4/28/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation

extension Notification.Name {
    static let initializationCompleted = Notification.Name("MBNotification-initializationCompleted")
    static let shouldDiscardInapps = Notification.Name("MBNotification-shouldDiscardInapps")
    static let mobileConfigDownloaded = Notification.Name("MBNotification-mobileConfigDownloaded")

    /// Carries the handled operation as `object` (an `ApplicationEvent`); live embedded blocks
    /// re-resolve their place with it, so an operation-targeted in-app can reach them.
    static let inAppOperationOccurred = Notification.Name("MBNotification-inAppOperationOccurred")
    static let receivedPushTokenKeepaliveFromTheMobileConfig = Notification.Name("MBNotification-receivedPushTokenKeepaliveFromTheMobileConfig")
}
