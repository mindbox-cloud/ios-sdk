//
//  InAppMessagesDelegate.swift
//  Mindbox
//
//  Created by Максим Казаков on 21.09.2022.
//

import Foundation
import UIKit
import MindboxLogger

/// `InAppMessagesDelegate` is a protocol that provides methods related to the behavior of in-app messages.
///
/// This protocol can be used to respond to events related to in-app messages, such as a message being tapped or dismissed.
/// In most cases, you would implement this protocol in your UIViewController or any other component responsible for handling in-app messages.
///
/// ## Protocol Conforming
///
/// To use the default implementations provided by the protocol extension, you can simply declare that your type conforms to the `InAppMessagesDelegate` protocol without needing to provide your own implementations of the `inAppMessageTapAction(id: URL?, payload: String)` and `inAppMessageDismissed(id: String)` methods:
///
///     class ViewController: UIViewController, InAppMessagesDelegate {
///         // No need to provide implementations for inAppMessageTapAction and inAppMessageDismissed
///     }
///
/// If you want to provide your own implementation for these methods, you can do so like this:
///
///     class ViewController: UIViewController, InAppMessagesDelegate {
///         func inAppMessageTapAction(id: String, url: URL?, payload: String) {
///             // Handle in-app message tap action
///         }
///
///         func inAppMessageDismissed(id: String) {
///             // Handle in-app message dismissed
///         }
///     }
public protocol InAppMessagesDelegate: AnyObject {
    /// Called when an in-app message is tapped by the user.
    ///
    /// Implement this method to handle the action that should be taken when an in-app message is tapped. This method provides the id of the message, an optional URL, and the payload as a string.
    ///
    /// - Parameters:
    ///   - id: The identifier of the in-app message.
    ///   - url: An optional URL to be handled when the in-app message is tapped.
    ///   - payload: The payload delivered with the in-app message.
    ///
    /// # Usage
    ///
    ///     func inAppMessageTapAction(id: String, url: URL?, payload: String) {
    ///         // Handle URL or payload data
    ///     }
    func inAppMessageTapAction(id: String, url: URL?, payload: String)

    /// Called when an in-app message is dismissed by the user.
    ///
    /// Implement this method to handle any action that should be taken when an in-app message is dismissed. This method provides the id of the message.
    ///
    /// - Parameter id: The identifier of the in-app message.
    ///
    /// # Usage
    ///
    ///     func inAppMessageDismissed(id: String) {
    ///         // Handle message dismissal
    ///     }
    func inAppMessageDismissed(id: String)
}

/// Provides a default implementation for the methods in the `InAppMessagesDelegate` protocol.
///
/// This extension is optional and provides default behavior for the methods in the protocol. You can override these methods in your own class or struct that conforms to `InAppMessagesDelegate` to provide custom behavior.

public extension InAppMessagesDelegate {
    func inAppMessageTapAction(id: String, url: URL?, payload: String) {
        Logger.common(message: "InAppMessagesDelegate inAppMessageTapAction called.")
    }

    func inAppMessageDismissed(id: String) { }
}
