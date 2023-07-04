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

/// A `CopyInappMessageHandler` class that conforms to the `InAppMessagesDelegate` protocol.
/// It provides specific implementations for handling In-App message tap actions and dismissals,
/// particularly for messages that require copying a payload to the clipboard.
public class CopyInappMessageHandler: InAppMessagesDelegate {
    private let pasteboard: UIPasteboard
    
    public init(pasteboard: UIPasteboard = UIPasteboard.general) {
        self.pasteboard = pasteboard
    }
    
    /// Handles the action when an In-App message is tapped.
    public func inAppMessageTapAction(id: String, url: URL?, payload: String) {
        Logger.common(message: "CopyInappMessageHandler inAppMessageTapAction called.")
        pasteboard.string = payload
    }
    
    /// Handles the action when an In-App message is dismissed.
    public func inAppMessageDismissed(id: String) {
        
    }
}
