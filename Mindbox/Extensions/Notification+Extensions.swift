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

    /// Every config download's end, whatever it brought, once its candidates are in hand; a superseded one is not posted.
    /// `Constants.Notification.sessionEpoch` (`Int`): the session the download started in.
    static let mobileConfigDownloadConcluded = Notification.Name("MBNotification-mobileConfigDownloadConcluded")

    /// Posted on main after every in-app session check, an expired session already reset. `Constants.Notification`:
    /// `sessionCheckStartedAt` (`TimeInterval`, on `CACurrentMediaTime()`) and `startsNewSession` (`Bool`).
    static let inappSessionChecked = Notification.Name("MBNotification-inappSessionChecked")

    /// Carries the handled operation as `object` (an `ApplicationEvent`); live embedded blocks
    /// re-resolve their place with it, so an operation-targeted in-app can reach them.
    static let inAppOperationOccurred = Notification.Name("MBNotification-inAppOperationOccurred")
    static let receivedPushTokenKeepaliveFromTheMobileConfig = Notification.Name("MBNotification-receivedPushTokenKeepaliveFromTheMobileConfig")
}
