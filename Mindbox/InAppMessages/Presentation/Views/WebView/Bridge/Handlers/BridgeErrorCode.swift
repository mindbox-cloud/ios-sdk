//
//  BridgeErrorCode.swift
//  Mindbox
//
//  Created by Sergei Semko on 9/29/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

/// Codes the SDK refuses a page's request with.
///
/// The page gets a message of type `error` with the request's `id` and the payload
/// `{ "error": "<code>" }`; the reason behind the code goes only to the SDK log.
enum BridgeErrorCode: String, CaseIterable, Error {
    /// The SDK does not know the action.
    case unknownAction = "unknown_action"
    /// The SDK knows the action but does not take it from a page, such as an action it sends itself.
    case notServed = "not_served"
    /// The block page is off screen, so an action on the user's behalf is refused.
    case notVisible = "not_visible"
    /// The payload is not a JSON object, or a field is missing or has a wrong type or value.
    case invalidPayload = "invalid_payload"
    /// A field names something the SDK does not support: a settings target, permission type or gesture.
    case unsupportedValue = "unsupported_value"
    /// The `openLink` URL does not parse.
    case invalidURL = "invalid_url"
    /// Not sent by the iOS SDK.
    case blockedScheme = "blocked_scheme"
    /// The system did not open the URL or the settings, or no screen could present Safari.
    case openFailed = "open_failed"
    /// The permission request failed.
    case permissionFailed = "permission_failed"
    /// None of the gestures asked for in `motion.start` is available on the device.
    case gesturesUnavailable = "gestures_unavailable"
    /// The `asyncOperation` could not be queued.
    case operationFailed = "operation_failed"
    /// The SDK found no in-app with the `showInApp` id to show.
    case unknownInapp = "unknown_inapp"
    /// The `showInApp` in-app did not appear: the app is in the background or presentation failed.
    case showFailed = "show_failed"
    /// The SDK could not handle a valid request.
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
