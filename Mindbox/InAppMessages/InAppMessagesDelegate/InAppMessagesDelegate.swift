//
//  InAppMessagesDelegate.swift
//  Mindbox
//
//  Created by Максим Казаков on 21.09.2022.
//

import Foundation
import UIKit
import MindboxLogger

/// A protocol that defines the methods a delegate of an In-App messaging service needs to implement.
public protocol InAppMessagesDelegate: AnyObject {
    /// This method is invoked when an In-App message is tapped.
    ///
    /// - Parameters:
    ///     - id: The unique identifier of the In-App message.
    ///     - url: An optional `URL` to be opened if the user taps on the message. If `nil`, no URL will be opened.
    ///     - payload: A `String` that contains additional data related to the In-App message.
    func inAppMessageTapAction(id: String, url: URL?, payload: String)
    
    /// This method is called when an In-App message is dismissed by the user.
    ///
    /// - Parameter id: The unique identifier of the dismissed In-App message.
    func inAppMessageDismissed(id: String)
}

public extension InAppMessagesDelegate {
    func inAppMessageTapAction(id: String, url: URL?, payload: String) {
        Logger.common(message: "InAppMessagesDelegate inAppMessageTapAction called.")
        if let url = url, UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }

        UIPasteboard.general.string = payload
    }
    
    func inAppMessageDismissed(id: String) {

    }
}
