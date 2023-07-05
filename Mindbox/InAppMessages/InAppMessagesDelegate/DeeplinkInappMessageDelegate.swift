//
//  DeeplinkInappMessageDelegate.swift
//  Mindbox
//
//  Created by vailence on 04.07.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation
import UIKit
import MindboxLogger

/// `DeeplinkInappMessageDelegate` is a protocol that extends the `InAppMessagesDelegate` and `MindboxURLHandlerDelegate` protocols.
///
/// It provides a default implementation for handling in-app messages with a URL, by opening the URL when an in-app message is tapped.
///
/// ## Protocol Conforming
///
/// Refer to `InAppMessagesDelegate` protocol documentation for information on conforming to `DeeplinkInappMessageDelegate` protocol.
public protocol DeeplinkInappMessageDelegate: InAppMessagesDelegate, MindboxURLHandlerDelegate { }

public extension DeeplinkInappMessageDelegate {
    func inAppMessageTapAction(id: String, url: URL?, payload: String) {
        Logger.common(message: "DeeplinkInappMessageDelegate inAppMessageTapAction called.")
        openURL(url)
    }

    func inAppMessageDismissed(id: String) { }
}
