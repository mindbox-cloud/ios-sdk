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

class HostSpy: WebBridgeHost {

    var contentId = "test-content-id"
    var logCategory: LogCategory = .webViewInAppMessages
    var tags: [String: String]?
    var presentingViewController: UIViewController?
    var isUserPresent = true

    var startPayload: JSONValue = .string("{}")

    private(set) var sent: [BridgeMessage] = []

    func send(_ message: BridgeMessage) {
        sent.append(message)
    }

    var holdsStartPayload = false
    private var parkedPayloadRequests: [(JSONValue) -> Void] = []

    func makeStartPayload(_ completion: @escaping (JSONValue) -> Void) {
        guard holdsStartPayload else {
            completion(startPayload)
            return
        }
        parkedPayloadRequests.append(completion)
    }

    func deliverStartPayload() {
        let parked = parkedPayloadRequests
        parkedPayloadRequests = []
        parked.forEach { $0(startPayload) }
    }
}

extension BridgeMessage {

    static func request(_ action: Action, payload: JSONValue? = nil) -> BridgeMessage {
        BridgeMessage(type: .request, action: action.rawValue, payload: payload)
    }
}

@MainActor
func drainMainQueue(until isDone: () -> Bool, turns: Int = 10) async {
    for _ in 0..<turns {
        guard !isDone() else { return }

        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
    }
}
