//
//  CompositeInappMessageDelegate .swift
//  Mindbox
//
//  Created by vailence on 04.07.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

/// `CompositeInappMessageDelegate` is a protocol that extends the `InAppMessagesDelegate` protocol.
///
/// It provides a way to handle in-app messages by delegating the actions to multiple delegates when an in-app message is tapped or dismissed.
///
/// ## Protocol Conforming
///
/// Refer to `InAppMessagesDelegate` protocol documentation for information on conforming to `CompositeInappMessageDelegate` protocol.
public protocol CompositeInappMessageDelegate: InAppMessagesDelegate {
    var delegates: [InAppMessagesDelegate] { get set }
}

public extension CompositeInappMessageDelegate {
    func inAppMessageTapAction(id: String, url: URL?, payload: String) {
        Logger.common(message: "CompositeInappMessageDelegate inAppMessageTapAction called.")
        delegates.forEach {
            $0.inAppMessageTapAction(id: id, url: url, payload: payload)
        }
    }

    func inAppMessageDismissed(id: String) {
        Logger.common(message: "CompositeInappMessageDelegate inAppMessageDismissed called.")
        delegates.forEach {
            $0.inAppMessageDismissed(id: id)
        }
    }
}
