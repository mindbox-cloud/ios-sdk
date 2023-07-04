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

/// A `URLInappMessageHandler` class that conforms to the `InAppMessagesDelegate` protocol.
/// It provides specific implementations for handling In-App message tap actions and dismissals.
public class URLInappMessageHandler: InAppMessagesDelegate {
    public init() {
        
    }
    
    /// Handles the action when an In-App message is tapped.
    public func inAppMessageTapAction(id: String, url: URL?, payload: String) {
        Logger.common(message: "URLInappMessageHandler inAppMessageTapAction called.")
        guard let url = url, UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
    
    /// Handles the action when an In-App message is dismissed.
    public func inAppMessageDismissed(id: String) {

    }
}
