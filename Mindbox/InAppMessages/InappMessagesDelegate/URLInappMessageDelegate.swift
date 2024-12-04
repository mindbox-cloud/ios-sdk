//
//  URLInappMessageDelegate.swift
//  Mindbox
//
//  Created by vailence on 04.07.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation
import UIKit
import MindboxLogger

/// `URLInappMessageDelegate` is a protocol that extends the `InAppMessagesDelegate` and `MindboxURLHandlerDelegate` protocols.
///
/// It provides a default implementation for handling in-app messages by opening an associated URL when an in-app message is tapped.
///
/// ## Protocol Conforming
///
/// Refer to `InAppMessagesDelegate` protocol documentation for information on conforming to `URLInappMessageDelegate` protocol.
public protocol URLInappMessageDelegate: InAppMessagesDelegate, MindboxURLHandlerDelegate { }

public extension URLInappMessageDelegate {
    func inAppMessageTapAction(id: String, url: URL?, payload: String) {
        Logger.common(message: "URLInappMessageDelegate inAppMessageTapAction called.")
        openURL(url)
    }

    func inAppMessageDismissed(id: String) { }
}
