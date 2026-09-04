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
class HostSpy: WebBridgeHost {

    var contentId = "test-content-id"
    var logCategory: LogCategory = .webViewInAppMessages
    var tags: [String: String]?
    /// A page that owns no controller unless a test hands it one.
    var presentingViewController: UIViewController?
    var isUserPresent = true

    /// What this page answers `ready` with. A plain stand-in: composing the real payload is
    /// the builder's own subject, not something every handler suite should drag in.
    var startPayload: JSONValue = .string("{}")

    private(set) var sent: [BridgeMessage] = []

    func send(_ message: BridgeMessage) {
        sent.append(message)
    }

    func makeStartPayload(_ completion: @escaping (JSONValue) -> Void) {
        completion(startPayload)
    }
}

extension BridgeMessage {

    /// A request as it arrives from JS: the action travels as a string, never as the enum.
    static func request(_ action: Action, payload: JSONValue? = nil) -> BridgeMessage {
        BridgeMessage(type: .request, action: action.rawValue, payload: payload)
    }
}

/// Lets the main queue run the work a handler scheduled on it, until `isDone` holds.
///
/// Opening a link hops through the main queue more than once — the handler defers, the system
/// answers on its own turn, and the answer is delivered on another — and each hop is only
/// enqueued while the previous one runs. Waiting a single turn would sample the state before
/// the later hops exist, which is exactly the kind of flake that passes locally and fails in CI.
@MainActor
func drainMainQueue(until isDone: () -> Bool, turns: Int = 10) async {
    for _ in 0..<turns {
        guard !isDone() else { return }

        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
    }
}
