//
//  BridgeMessage.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 26.01.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

@_spi(Internal)
public enum JSONValue: Codable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
        } else if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            self = .double(doubleValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let objectValue = try? container.decode([String: JSONValue].self) {
            self = .object(objectValue)
        } else if let arrayValue = try? container.decode([JSONValue].self) {
            self = .array(arrayValue)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported JSON value"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    init?(any: Any?) {
        guard let any else {
            return nil
        }
        switch any {
        case is NSNull:
            self = .null
        case let value as JSONValue:
            self = value
        case let value as String:
            self = .string(value)
        case let value as Bool:
            self = .bool(value)
        case let value as Int:
            self = .int(value)
        case let value as Int64:
            self = .int(Int(value))
        case let value as Double:
            self = .double(value)
        case let value as Float:
            self = .double(Double(value))
        case let value as [String: Any]:
            var object: [String: JSONValue] = [:]
            for (key, entry) in value {
                guard let jsonValue = JSONValue(any: entry) else { return nil }
                object[key] = jsonValue
            }
            self = .object(object)
        case let value as [Any]:
            var array: [JSONValue] = []
            array.reserveCapacity(value.count)
            for entry in value {
                guard let jsonValue = JSONValue(any: entry) else { return nil }
                array.append(jsonValue)
            }
            self = .array(array)
        default:
            return nil
        }
    }

    var doubleValue: Double? {
        switch self {
        case .double(let v): return v
        case .int(let v): return Double(v)
        case .string(let v): return Double(v)
        default: return nil
        }
    }

    var anyValue: Any? {
        switch self {
        case .string(let value):
            return value
        case .int(let value):
            return value
        case .double(let value):
            return value
        case .bool(let value):
            return value
        case .object(let value):
            return value.mapValues { $0.containerValue }
        case .array(let value):
            return value.map { $0.containerValue }
        case .null:
            return nil
        }
    }

    private var containerValue: Any {
        anyValue ?? NSNull()
    }

    static func mergingInAppTags(_ tags: [String: String]?, into body: JSONValue) -> JSONValue {
        guard let tags, !tags.isEmpty else { return body }
        guard case .object(var dict) = body else { return body }

        switch dict["tags"] {
        case .none, .some(.null):
            dict["tags"] = .object(tags.mapValues { .string($0) })
        case .some(.object(var existingTags)):
            for (key, value) in tags {
                if existingTags[key] != nil {
                    Logger.common(
                        message: "[WebView] Tags merge: key '\(key)' already present in operation body, keeping client value",
                        category: .inAppMessages
                    )
                    continue
                }
                existingTags[key] = .string(value)
            }
            dict["tags"] = .object(existingTags)
        default:
            Logger.common(
                message: "[WebView] Tags merge: 'tags' in operation body is not an object, keeping client value",
                category: .inAppMessages
            )
        }

        return .object(dict)
    }
}

/// A message between the SDK and a page over the JS bridge.
///
/// ```json
/// { "version": 1, "type": "request", "action": "ready", "payload": "{}", "id": "<UUID>", "timestamp": 1760950000000 }
/// ```
///
/// A page's message without `version`, `type`, `action`, a UUID `id` or an integer `timestamp` gets no
/// answer. A page may send `payload` as a JSON string or an object; the SDK always sends a JSON string,
/// so parse it with `JSON.parse()`. An answer carries the request's `id` in lowercase. An overlay that
/// answers an SDK request with an `error` is closed.
@_spi(Internal)
public struct BridgeMessage: Codable {
    public enum MessageType: String, Codable {
        case request
        case response
        case error
    }

    enum Action: String, CaseIterable {

        // MARK: JS → Native: Lifecycle

        /// Closes the overlay; on a block page it does nothing.
        ///
        /// - Payload:
        ///   ```json
        ///   {}
        ///   ```
        /// - Response:
        ///   ```json
        ///   { "success": true }
        ///   ```
        case close

        /// Shows the overlay once its content is ready; an overlay that does not send it within 7 s is
        /// closed. On a block page it does nothing.
        ///
        /// - Payload:
        ///   ```json
        ///   {}
        ///   ```
        /// - Response:
        ///   ```json
        ///   { "success": true }
        ///   ```
        case `init`

        /// Runs an in-app action as a tap on a native in-app does, without sending `Inapp.Click`; the
        /// overlay stays open until ``close``. On a block page it does nothing.
        ///
        /// - Payload:
        ///   ```json
        ///   { "$type": "redirectUrl", "value": "https://example.com", "intentPayload": "promo123" }
        ///   ```
        ///   ```json
        ///   { "$type": "pushPermission", "intentPayload": "promo123" }
        ///   ```
        /// - Response:
        ///   ```json
        ///   { "success": true }
        ///   ```
        case click

        /// Hides the overlay without closing it; ``init`` shows it again. On a block page it does nothing.
        ///
        /// - Payload:
        ///   ```json
        ///   {}
        ///   ```
        /// - Response:
        ///   ```json
        ///   { "success": true }
        ///   ```
        case hide

        /// Asks for the start data once the page's bridge can take messages.
        ///
        /// - Payload:
        ///   ```json
        ///   {}
        ///   ```
        /// - Response:
        ///   ```json
        ///   {
        ///     "sdkVersion": "2.15.0",
        ///     "sdkVersionNumeric": "11",
        ///     "endpointId": "my-app-endpoint",
        ///     "deviceUUID": "A1B2C3D4-E5F6-7890-ABCD-EF1234567890",
        ///     "userVisitCount": "41",
        ///     "inappId": "65f3a8b9-2c4d-4e5f-a6b7-c8d9e0f12345",
        ///     "firstInitializationDateTime": "2025-01-15T10:30:00Z",
        ///     "localStateVersion": 1,
        ///     "operationName": "Inapp.Click",
        ///     "operationBody": "{\"inappId\":\"...\"}",
        ///     "trackVisitSource": "link",
        ///     "trackVisitRequestUrl": "https://example.com/page",
        ///     "permissions": {
        ///       "notifications": { "status": "granted" }
        ///     },
        ///     "insets": { "top": 47, "left": 0, "bottom": 34, "right": 0 },
        ///     "theme": "light",
        ///     "platform": "ios",
        ///     "locale": "en_US",
        ///     "version": "1.2.3"
        ///   }
        ///   ```
        ///
        /// `operationName`, `operationBody`, `trackVisitSource`, `trackVisitRequestUrl`,
        /// `firstInitializationDateTime` and `version` (the app version) are present only when known.
        /// `permissions` lists only granted ones, under `notifications`, `camera`, `microphone`,
        /// `photoLibrary` and `location`. Params from the in-app config are added at the root.
        case ready

        // MARK: JS → Native: Info

        /// Writes the payload to the SDK log.
        ///
        /// - Payload:
        ///   ```json
        ///   { "message": "<string>" }
        ///   ```
        /// - Response:
        ///   ```json
        ///   { "success": true }
        ///   ```
        case log

        // MARK: JS → Native: Operations

        /// Queues a Mindbox operation; `success` means queued, not delivered.
        ///
        /// `inappId`, this page's in-app when omitted, names the in-app whose tags the SDK adds to
        /// `body.tags` when in-app tags are enabled.
        ///
        /// - Payload:
        ///   ```json
        ///   { "operation": "<string>", "body": { ... }, "inappId": "<string, optional>" }
        ///   ```
        /// - Response:
        ///   ```json
        ///   { "success": true }
        ///   ```
        /// - Errors: `invalid_payload`, `operation_failed`.
        case asyncOperation

        /// Sends a Mindbox operation and answers with the backend's response; `inappId` works as in
        /// ``asyncOperation``.
        ///
        /// - Payload:
        ///   ```json
        ///   { "operation": "<string>", "body": { ... }, "inappId": "<string, optional>" }
        ///   ```
        /// - Response, on HTTP 2xx: the response body as received, a `ValidationError` one included:
        ///   ```json
        ///   { "status": "Success", ... }
        ///   ```
        /// - Error, on HTTP 3xx–5xx, no connection or an SDK failure, for example:
        ///   ```json
        ///   { "status": "ProtocolError", "errorMessage": "<string>", "errorId": "<string>", "httpStatusCode": "400" }
        ///   ```
        ///   ```json
        ///   { "errorMessage": "Connection error", "httpStatusCode": "null" }
        ///   ```
        /// - Errors: also `invalid_payload`.
        case syncOperation

        // MARK: JS → Native: Navigation, Settings & Permissions

        /// Opens a URL outside the page: `http` and `https` in the app that claims the link or in an
        /// in-app Safari sheet, other schemes through the system. Answers once the URL is open.
        ///
        /// - Payload:
        ///   ```json
        ///   { "url": "https://example.com/product/123" }
        ///   ```
        /// - Response:
        ///   ```json
        ///   { "success": true }
        ///   ```
        /// - Errors: `invalid_payload`, `invalid_url`, `open_failed`, `not_visible`.
        case openLink

        /// Opens the app's notification settings (`notifications`) or its settings page (`application`)
        /// in the Settings app.
        ///
        /// - Payload:
        ///   ```json
        ///   { "target": "notifications" | "application" }
        ///   ```
        /// - Response:
        ///   ```json
        ///   { "success": true }
        ///   ```
        /// - Errors: `invalid_payload`, `unsupported_value`, `open_failed`, `not_visible`.
        case settingsOpen = "settings.open"

        /// Requests the push notification permission. The system dialog appears only until the user
        /// decides; after that only Settings can change it, see ``settingsOpen``.
        ///
        /// - Payload:
        ///   ```json
        ///   { "type": "pushNotifications" }
        ///   ```
        /// - Response:
        ///   ```json
        ///   { "result": "granted" | "denied", "dialogShown": true | false }
        ///   ```
        /// - Errors: `invalid_payload`, `unsupported_value`, `permission_failed`, `not_visible`.
        case permissionRequest = "permission.request"

        // MARK: JS → Native: Local State

        /// Reads string values from the key-value storage shared by the app's pages; an empty `data` list
        /// reads all of them.
        ///
        /// - Payload:
        ///   ```json
        ///   { "data": ["key1", "key2"] }
        ///   ```
        /// - Payload (get all):
        ///   ```json
        ///   { "data": [] }
        ///   ```
        /// - Response:
        ///   ```json
        ///   { "data": { "key1": "value1", "key2": null }, "version": 1 }
        ///   ```
        /// - Errors: `invalid_payload`.
        case localStateGet = "localState.get"

        /// Writes values: `null` deletes a key, a value that is not a string is stored as its JSON text.
        /// Other open pages get ``localStateChanged``.
        ///
        /// - Payload:
        ///   ```json
        ///   { "data": { "key1": "value1", "key2": null } }
        ///   ```
        /// - Response: the written keys with the current version:
        ///   ```json
        ///   { "data": { "key1": "value1", "key2": null }, "version": 1 }
        ///   ```
        /// - Errors: `invalid_payload`.
        case localStateSet = "localState.set"

        /// Sets the storage version and writes values without telling other pages; the version is
        /// overwritten, not compared.
        ///
        /// - Payload:
        ///   ```json
        ///   { "data": { "key1": "defaultValue1" }, "version": 1 }
        ///   ```
        /// - Response: the written keys with the new version:
        ///   ```json
        ///   { "data": { "key1": "defaultValue1" }, "version": 1 }
        ///   ```
        /// - Errors: `invalid_payload`.
        case localStateInit = "localState.init"

        // MARK: JS → Native: Haptic

        /// Plays haptic feedback; answers `success` even when nothing plays.
        ///
        /// **Selection** — light tick:
        /// ```json
        /// { "type": "selection" }
        /// ```
        ///
        /// **Impact** — single tap:
        /// ```json
        /// { "type": "impact", "style": "light" | "medium" | "heavy" | "soft" | "rigid" }
        /// ```
        ///
        /// **Notification** — system notification feedback:
        /// ```json
        /// { "type": "notification", "style": "success" | "warning" | "error" }
        /// ```
        ///
        /// **Pattern** — `time` and `duration` in ms, `intensity` and `sharpness` from 0 to 1; up to 128
        /// events, each at most 5 s long, all within 30 s:
        /// ```json
        /// {
        ///   "type": "pattern",
        ///   "pattern": [
        ///     { "time": 0, "duration": 50, "intensity": 0.8, "sharpness": 1.0 },
        ///     { "time": 150, "duration": 50, "intensity": 0.6, "sharpness": 0.5 }
        ///   ]
        /// }
        /// ```
        ///
        /// - Response:
        ///   ```json
        ///   { "success": true }
        ///   ```
        /// - Errors: `not_visible`.
        case haptic

        // MARK: JS → Native: Motion

        /// Starts reporting the listed gestures through ``motionEvent``, replacing the previous
        /// subscription; `shake` reaches overlays only.
        ///
        /// - Payload:
        ///   ```json
        ///   { "gestures": ["shake", "flip"] }
        ///   ```
        /// - Response (all gestures started):
        ///   ```json
        ///   { "success": true }
        ///   ```
        /// - Response (some gestures unavailable, the rest started):
        ///   ```json
        ///   { "success": true, "unavailable": ["flip"] }
        ///   ```
        /// - Error, when no requested gesture is available on the device:
        ///   ```json
        ///   { "error": "gestures_unavailable" }
        ///   ```
        /// - Errors: also `invalid_payload`, `unsupported_value`, `not_visible`.
        case motionStart = "motion.start"

        /// Stops all motion reporting.
        ///
        /// - Payload:
        ///   ```json
        ///   {}
        ///   ```
        /// - Response:
        ///   ```json
        ///   { "success": true }
        ///   ```
        case motionStop = "motion.stop"

        // MARK: Native → JS: Motion

        /// Reports a gesture the page subscribed to with ``motionStart``.
        ///
        /// **Shake**:
        /// ```json
        /// { "gesture": "shake" }
        /// ```
        ///
        /// **Flip** — sent on every change between `faceUp`, `faceDown`, `portrait`, `portraitUpsideDown`,
        /// `landscapeLeft` and `landscapeRight`, not for the position at start; filter by `to`:
        /// ```json
        /// { "gesture": "flip", "from": "portrait", "to": "faceDown" }
        /// ```
        case motionEvent = "motion.event"

        // MARK: Native → JS: Navigation

        /// Reports a link or form navigation the SDK cancelled in the page.
        ///
        /// - Payload:
        ///   ```json
        ///   { "url": "<string>" }
        ///   ```
        case navigationIntercepted

        // MARK: JS → Native: Embedded pages

        /// Asks which of the listed in-apps the page may show. The answer can wait for a network
        /// request; with no config within 30 s it is an empty list.
        ///
        /// - Payload:
        ///   ```json
        ///   { "inappIds": ["<string>", "..."] }
        ///   ```
        /// - Response: the ids that may be shown, in any order:
        ///   ```json
        ///   { "inappIds": ["<string>", "..."] }
        ///   ```
        /// - Errors: `invalid_payload`.
        case filterShowableInapps

        /// Reports how many items the page rendered, once per load and after each ``initDataUpdated``;
        /// zero means nothing to show.
        ///
        /// - Payload:
        ///   ```json
        ///   { "count": <int> }
        ///   ```
        /// - Response:
        ///   ```json
        ///   { "success": true }
        ///   ```
        /// - Errors: `invalid_payload` (`count` is not a whole number of zero or more), which can fail the
        ///   block.
        case contentRendered

        /// Shows an in-app over the screen by id; `params` override the in-app's own params in its start
        /// data (see ``ready``). An overlay that asks closes when the new in-app starts to show, without an
        /// answer.
        ///
        /// - Payload:
        ///   ```json
        ///   { "inappId": "<string>", "params": { } }
        ///   ```
        /// - Response, once the in-app is on screen:
        ///   ```json
        ///   { "success": true }
        ///   ```
        /// - Errors: `invalid_payload`, `unknown_inapp`, `show_failed`, `not_visible`.
        case showInApp

        // MARK: Native → JS: Embedded pages

        /// Sends a block page the full start data again without reloading it. Confirm it with a
        /// `response`: with no confirmation after 7 s on screen, the SDK may rebuild the page.
        ///
        /// - Payload: the same JSON as the ``ready`` response.
        /// - Response:
        ///   ```json
        ///   { "success": true }
        ///   ```
        /// - Error, when the page cannot use the payload:
        ///   ```json
        ///   { "error": "<string>" }
        ///   ```
        case initDataUpdated

        /// Tells every other open page that has sent ``ready`` about a ``localStateSet`` write.
        ///
        /// - Payload: the ``localStateSet`` response; `null` means the key was deleted.
        ///   ```json
        ///   { "data": { "<key>": "<string>" }, "version": <int> }
        ///   ```
        /// - Response:
        ///   ```json
        ///   { "success": true }
        ///   ```
        /// - Error, when the page cannot use the payload:
        ///   ```json
        ///   { "error": "<string>" }
        ///   ```
        case localStateChanged = "localState.changed"

        var requiresUserPresence: Bool {
            switch self {
            case .openLink, .settingsOpen, .permissionRequest:
                return true

            case .haptic:
                return true

            case .motionStart:
                return true

            case .showInApp:
                return true

            case .motionStop, .ready, .close, .`init`, .click, .hide, .log,
                 .contentRendered, .filterShowableInapps,
                 .asyncOperation, .syncOperation,
                 .localStateGet, .localStateSet, .localStateInit,
                 .motionEvent, .navigationIntercepted,
                 .initDataUpdated, .localStateChanged:
                return false
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case version, type, action, payload, id, timestamp
    }

    public let version: Int
    public let type: MessageType
    public let action: String
    public let payload: JSONValue?
    public let id: UUID
    public let timestamp: Int64

    var parsedAction: Action? { Action(rawValue: action) }

    var payloadObject: [String: JSONValue]? {
        if case .string(let string) = payload,
           let data = string.data(using: .utf8),
           let object = try? JSONDecoder().decode([String: JSONValue].self, from: data) {
            return object
        }

        if case .object(let object) = payload {
            return object
        }

        return nil
    }

    var payloadString: String {
        if case .string(let value) = payload {
            return value
        }

        if let payload,
           let data = try? JSONEncoder().encode(payload),
           let string = String(data: data, encoding: .utf8) {
            return string
        }

        return ""
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(type, forKey: .type)
        try container.encode(action, forKey: .action)

        if let payload {
            switch payload {
            case .string(let value):
                try container.encode(value, forKey: .payload)
            case .null:
                try container.encodeNil(forKey: .payload)
            default:
                if let data = try? JSONEncoder().encode(payload),
                   let str = String(data: data, encoding: .utf8) {
                    try container.encode(str, forKey: .payload)
                } else {
                    try container.encode("", forKey: .payload)
                }
            }
        } else {
            try container.encodeNil(forKey: .payload)
        }

        try container.encode(id.uuidString.lowercased(), forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
    }

    public init(
        type: MessageType,
        action: String,
        payload: JSONValue?,
        id: UUID = UUID(),
        timestamp: Int64 = BridgeMessage.currentTimestampMs()
    ) {
        self.version = Constants.Versions.webBridgeVersion
        self.type = type
        self.action = action
        self.payload = payload
        self.id = id
        self.timestamp = timestamp
    }

    init(
        type: MessageType,
        action: Action,
        payload: JSONValue?,
        id: UUID = UUID(),
        timestamp: Int64 = BridgeMessage.currentTimestampMs()
    ) {
        self.init(type: type, action: action.rawValue, payload: payload, id: id, timestamp: timestamp)
    }

    init?(
        type: MessageType,
        action: String,
        payload: Any?,
        id: UUID = UUID(),
        timestamp: Int64 = BridgeMessage.currentTimestampMs()
    ) {
        if payload == nil {
            self.payload = nil
        } else if let jsonPayload = JSONValue(any: payload) {
            self.payload = jsonPayload
        } else {
            return nil
        }

        self.version = Constants.Versions.webBridgeVersion
        self.type = type
        self.action = action
        self.id = id
        self.timestamp = timestamp
    }

    public var payloadAny: Any? {
        payload?.anyValue
    }

    static func from(body: Any) -> BridgeMessage? {
        if let data = body as? Data {
            return try? JSONDecoder().decode(BridgeMessage.self, from: data)
        }
        if let jsonString = body as? String,
           let data = jsonString.data(using: .utf8) {
            return try? JSONDecoder().decode(BridgeMessage.self, from: data)
        }
        if JSONSerialization.isValidJSONObject(body),
           let data = try? JSONSerialization.data(withJSONObject: body) {
            return try? JSONDecoder().decode(BridgeMessage.self, from: data)
        }
        return nil
    }

    func jsonString() -> String? {
        guard let data = try? JSONEncoder().encode(self),
              let json = String(data: data, encoding: .utf8) else {
            return nil
        }
        return json
    }

    public static func currentTimestampMs() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }

    func prettyPayloadDescription() -> String {
        guard let payload = payload else {
            return "nil"
        }

        func prettyJSON(from data: Data) -> String? {
            guard let jsonObject = try? JSONSerialization.jsonObject(with: data),
                  let prettyData = try? JSONSerialization.data(
                    withJSONObject: jsonObject,
                    options: [.prettyPrinted, .sortedKeys]
                  ),
                  let prettyString = String(data: prettyData, encoding: .utf8) else {
                return nil
            }
            return prettyString
        }

        switch payload {
        case .string(let stringValue):
            if let data = stringValue.data(using: .utf8),
               let pretty = prettyJSON(from: data) {
                return pretty
            }
            return stringValue

        case .object, .array:
            if let data = try? JSONEncoder().encode(payload),
               let pretty = prettyJSON(from: data) {
                return pretty
            }
            return String(describing: payloadAny)

        default:
            return String(describing: payloadAny)
        }
    }
}
