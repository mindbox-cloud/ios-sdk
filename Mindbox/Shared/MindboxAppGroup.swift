//
//  MindboxAppGroup.swift
//  Mindbox
//
//  Copyright © 2026 Mindbox. All rights reserved.
//
//  Shared with MindboxNotifications: see the note in PushDeliveryConfirmation.swift.
//

import Foundation

/// The App Group the SDK documents for the app and its extensions.
@_spi(Internal)
public enum MindboxAppGroup {

    /// `group.cloud.Mindbox.<bundle id of the host app>`.
    public static func identifier(hostAppBundleIdentifier: String) -> String {
        "group.cloud.Mindbox.\(hostAppBundleIdentifier)"
    }
}
