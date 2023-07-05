//
//  CopyInappMessageDelegate.swift
//  Mindbox
//
//  Created by vailence on 04.07.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation
import UIKit
import MindboxLogger

/// `CopyInappMessageDelegate` is a protocol that extends the `InAppMessagesDelegate` and `MindboxPayloadCopierDelegate` protocols.
///
/// It provides a default implementation for handling in-app messages by copying the payload when an in-app message is tapped.
///
/// ## Protocol Conforming
///
/// Refer to `InAppMessagesDelegate` protocol documentation for information on conforming to `CopyInappMessageDelegate` protocol.
public protocol CopyInappMessageDelegate: InAppMessagesDelegate, MindboxPayloadCopierDelegate { }

public extension CopyInappMessageDelegate {
    func inAppMessageTapAction(id: String, url: URL?, payload: String) {
        Logger.common(message: "CopyInappMessageDelegte inAppMessageTapAction called.")
        copyPayload(payload)
    }
    
    func inAppMessageDismissed(id: String) { }
}
