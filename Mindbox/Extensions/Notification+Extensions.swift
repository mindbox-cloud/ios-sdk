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
}
