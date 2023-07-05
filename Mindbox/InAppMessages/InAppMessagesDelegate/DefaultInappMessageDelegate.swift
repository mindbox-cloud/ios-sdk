//
//  DefaultInappMessageDelegate.swift
//  Mindbox
//
//  Created by vailence on 05.07.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

/// `DefaultInappMessageDelegate` is a protocol that extends the `InAppMessagesDelegate`, `MindboxURLHandlerDelegate`, and `MindboxPayloadCopierDelegate` protocols.
///
/// It provides a default implementation for handling in-app messages by opening an associated URL and copying the payload (if it is a plain string) when an in-app message is tapped.
///
/// ## Protocol Conforming
///
/// Refer to `InAppMessagesDelegate` protocol documentation for information on conforming to `DefaultInappMessageDelegate` protocol.
public protocol DefaultInappMessageDelegate: InAppMessagesDelegate, MindboxURLHandlerDelegate, MindboxPayloadCopierDelegate {
    func inAppMessageTapAction(id: String, url: URL?, payload: String)
    func inAppMessageDismissed(id: String)
}

public extension DefaultInappMessageDelegate {
    func inAppMessageTapAction(id: String, url: URL?, payload: String) {
        Logger.common(message: "InAppMessagesDelegate inAppMessageTapAction called.")
        openURL(url)
        copyPayload(payload)
    }
    
    func inAppMessageDismissed(id: String) { }
}
