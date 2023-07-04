//
//  CompositeInappMessageDelegate .swift
//  Mindbox
//
//  Created by vailence on 04.07.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

/// A `CompositeInappMessageDelegate` protocol that conforms to the `InAppMessagesDelegate` protocol.
/// It provides an array of delegate objects to which In-App message tap actions and dismissals are forwarded.
public protocol CompositeInappMessageDelegate: InAppMessagesDelegate {
    /// An array of `InAppMessagesDelegate` objects to which In-App message events are delegated.
    var delegates: [InAppMessagesDelegate] { get set }
}

extension CompositeInappMessageDelegate {
    /// Handles the action when an In-App message is tapped.
    ///
    /// In this implementation, a log message is generated to indicate that the `inAppMessageTapAction` method was called. The tap action is then forwarded to each delegate object in the `delegates` array.
    public func inAppMessageTapAction(id: String, url: URL?, payload: String) {
        Logger.common(message: "CompositeInappMessageDelegate inAppMessageTapAction called.")
        delegates.forEach {
            $0.inAppMessageTapAction(id: id, url: url, payload: payload)
        }
    }
    
    /// Handles the action when an In-App message is dismissed.
    ///
    /// In this implementation, a log message is generated to indicate that the `inAppMessageDismissed` method was called. The dismissal action is then forwarded to each delegate object in the `delegates` array.
    public func inAppMessageDismissed(id: String) {
        Logger.common(message: "CompositeInappMessageDelegate inAppMessageDismissed called.")
        delegates.forEach {
            $0.inAppMessageDismissed(id: id)
        }
    }
}
