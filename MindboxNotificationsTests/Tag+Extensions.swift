//
//  Tag+Extensions.swift
//  MindboxNotificationsTests
//
//  Created by Sergei Semko on 6/16/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import Testing

extension Tag {
    /// Umbrella tag applied to every MindboxNotifications test.
    @Tag static var notifications: Self

    // MARK: Subject areas

    /// Push-format detection, decoding and validation: strategy factory, legacy/current
    /// strategies, formatter, validator, payload parsing and `MBPushNotification`.
    @Tag static var pushParsing: Self

    /// Image magic-byte format detection (`ImageFormat`).
    @Tag static var imageFormat: Self

    /// Notification Service Extension delivery flow (`didReceive(_:withContentHandler:)`, expiry, push delivered).
    @Tag static var notificationService: Self

    /// Notification Content Extension UI flow (`didReceive(notification:…)`, actions, image view).
    @Tag static var notificationContent: Self
}
