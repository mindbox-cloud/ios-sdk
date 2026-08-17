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

    /// An operation the in-app pipeline agreed to handle, carried as the notification's `object`
    /// (an `ApplicationEvent`). This is the push side of embedded blocks: a live block re-resolves
    /// its place with the operation, so an operation-targeted in-app can reach it.
    static let inAppOperationOccurred = Notification.Name("MBNotification-inAppOperationOccurred")
    static let receivedPushTokenKeepaliveFromTheMobileConfig = Notification.Name("MBNotification-receivedPushTokenKeepaliveFromTheMobileConfig")
}
