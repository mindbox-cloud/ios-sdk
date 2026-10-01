//
//  BridgeErrorCode.swift
//  Mindbox
//
//  Created by Sergei Semko on 9/29/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

/// Refusal codes of the JS bridge. The raw values are the wire contract with the web pages.
enum BridgeErrorCode: String, CaseIterable, Error {
    case unknownAction = "unknown_action"
    case notServed = "not_served"
    case notVisible = "not_visible"
    case invalidPayload = "invalid_payload"
    case unsupportedValue = "unsupported_value"
    case invalidURL = "invalid_url"
    case blockedScheme = "blocked_scheme"
    case openFailed = "open_failed"
    case permissionFailed = "permission_failed"
    case gesturesUnavailable = "gestures_unavailable"
    case operationFailed = "operation_failed"
    case unknownInapp = "unknown_inapp"
    case showFailed = "show_failed"
    case internalError = "internal_error"
}

extension BridgeMessage {

    static func refusal(_ code: BridgeErrorCode, to request: BridgeMessage) -> BridgeMessage {
        BridgeMessage(type: .error,
                      action: request.action,
                      payload: .object(["error": .string(code.rawValue)]),
                      id: request.id)
    }
}
