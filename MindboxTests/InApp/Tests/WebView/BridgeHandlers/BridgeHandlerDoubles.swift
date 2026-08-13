//
//  BridgeHandlerDoubles.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit
import MindboxLogger
@_spi(Internal) @testable import Mindbox

/// A page that records what it was told to send.
///
/// Everything a handler could want from a real page is inert here: these suites are about what
/// a handler does with a message, not about any particular surface.
final class HostSpy: WebBridgeHost {

    var contentId = "test-content-id"
    var logCategory: LogCategory = .webViewInAppMessages
    var tags: [String: String]?
    var presentingViewController: UIViewController? { nil }
    var isUserPresent = true

    private(set) var sent: [BridgeMessage] = []

    func send(_ message: BridgeMessage) {
        sent.append(message)
    }
}

extension BridgeMessage {

    /// A request as it arrives from JS: the action travels as a string, never as the enum.
    static func request(_ action: Action, payload: JSONValue? = nil) -> BridgeMessage {
        BridgeMessage(type: .request, action: action.rawValue, payload: payload)
    }
}
