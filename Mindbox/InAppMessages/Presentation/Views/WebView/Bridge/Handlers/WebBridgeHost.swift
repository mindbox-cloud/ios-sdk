//
//  WebBridgeHost.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit
import MindboxLogger

protocol WebBridgeHost: AnyObject {

    var contentId: String { get }

    var logCategory: LogCategory { get }

    var tags: [String: String]? { get }

    var presentingViewController: UIViewController? { get }

    var isUserPresent: Bool { get }

    func send(_ message: BridgeMessage)

    func makeStartPayload(_ completion: @escaping (JSONValue) -> Void)
}

// MARK: - Answering a request

extension WebBridgeHost {

    func respond(to message: BridgeMessage, payload: JSONValue) {
        send(BridgeMessage(type: .response, action: message.action, payload: payload, id: message.id))
    }

    func respondSuccess(to message: BridgeMessage) {
        respond(to: message, payload: .object(["success": .bool(true)]))
    }

    func respondError(_ code: BridgeErrorCode, detail: String, to message: BridgeMessage) {
        Logger.common(message: "[WebView] Bridge: '\(message.action)' \(message.id) refused with \(code.rawValue) for '\(contentId)': \(detail)",
                      level: .error,
                      category: logCategory)

        send(.refusal(code, to: message))
    }
}

// MARK: - Acting on the user's behalf

extension WebBridgeHost {

    func requireUserPresence(for message: BridgeMessage) -> Bool {
        guard !isUserPresent else { return true }

        respondError(.notVisible, detail: "nobody is looking at this page", to: message)
        return false
    }
}

// MARK: - Capabilities

protocol WebBridgeLifecycleHosting: AnyObject {

    func bridgeDidInit()

    func bridgeDidRequestClose()

    func bridgeDidRequestHide()

    func bridgeDidClick(rawPayload: String)
}

protocol WebBridgeContentHosting: AnyObject {

    func bridgeDidRenderContent(count: Int)

    func bridgeDidReportUnreadableContent()
}

protocol WebBridgeInappRequestHosting: AnyObject {

    func bridgeDidAskShowableInapps(_ ids: [String], completion: @escaping ([String]) -> Void)

    func bridgeDidRequestShowInApp(id: String,
                                   params: [String: JSONValue],
                                   completion: @escaping (Result<Void, BridgeErrorCode>) -> Void)
}
