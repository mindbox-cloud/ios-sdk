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
/// A page's message needs `version` 1 or higher, `type`, `action`, a UUID `id` and `timestamp`; one
/// without them gets no answer. The SDK answers a request with its `id` in lowercase. A page may send
/// a payload as a JSON string or as an object; every payload the SDK sends is a JSON string: parse it
/// with `JSON.parse()`. An overlay that answers an SDK request with an `error` is closed; an `error`
/// answer from a block page is dropped.
@_spi(Internal)
public struct BridgeMessage: Codable {
    public enum MessageType: String, Codable {
        case request
        case response
        case error
    }

    enum Action: String, CaseIterable {

        // MARK: JS → Native: Lifecycle

        /// Closes the overlay. A block page gets `success` and nothing happens.
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

        /// Shows the overlay once its content is ready. A block page gets `success` and nothing happens.
        ///
        /// An overlay that does not send it within 7 seconds of starting to load, or of the app's return to
        /// the foreground, is closed. Sent after ``hide``, it shows the overlay again.
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

        /// Reports a tap. The overlay runs the action and passes its URL and `intentPayload` to the app's
        /// in-app delegate, as a native in-app does, but stays open and sends no `Inapp.Click`: send
        /// ``close`` to close it. A block page gets `success` and nothing happens.
        ///
        /// The payload is an in-app action: `redirectUrl` with `value` (the URL) and `intentPayload`,
        /// or `pushPermission` with `intentPayload`; any other payload is ignored.
        ///
        /// - Payload:
        ///   ```json
        ///   { "$type": "redirectUrl", "value": "https://example.com", "intentPayload": "promo123" }
        ///   ```
        /// - Response:
        ///   ```json
        ///   { "success": true }
        ///   ```
        case click

        /// Hides the overlay without closing it: it turns transparent and stops taking touches. A block
        /// page gets `success` and nothing happens.
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
        /// `operationName` and `operationBody` (the operation that triggered the in-app, its body as a JSON
        /// string), `trackVisitSource`, `trackVisitRequestUrl`, `firstInitializationDateTime` and `version`
        /// (the app version) are present only when known. `permissions` lists only granted permissions, `{}`
        /// when there are none; limited photo library access adds `"details": { "access": "limited" }`.
        /// Params from the in-app config are added at the root and replace SDK keys of the same name, except
        /// the operation and track visit keys.
        case ready

        // MARK: JS → Native: Info

        /// Writes the whole payload, as sent, to the SDK log.
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

        /// Queues a Mindbox operation for sending.
        ///
        /// `success` means queued, not delivered. Like an operation the app sends, it can trigger in-apps.
        /// When `body` is an object and in-app tags are enabled, the SDK adds the in-app's tags to
        /// `body.tags`, keeping every key the page set. `inappId` names the in-app: omitted or `null` means
        /// this page's own; an in-app missing from the current config adds no tags.
        ///
        /// - Payload:
        ///   ```json
        ///   { "operation": "<string>", "body": { ... }, "inappId": "<string, optional>" }
        ///   ```
        /// - Response:
        ///   ```json
        ///   { "success": true }
        ///   ```
        /// - Errors: `invalid_payload` (no `operation` or `body`, or an `inappId` that is neither a
        ///   non-empty string nor `null`), `operation_failed` (the operation could not be queued).
        case asyncOperation

        /// Sends a Mindbox operation at once and answers with the backend's reply.
        ///
        /// In-app triggering, tags, `inappId` and `invalid_payload` work as in ``asyncOperation``.
        ///
        /// - Payload:
        ///   ```json
        ///   { "operation": "<string>", "body": { ... }, "inappId": "<string, optional>" }
        ///   ```
        /// - Response, on HTTP 2xx: the response body as received, a `ValidationError` one included:
        ///   ```json
        ///   { "status": "Success", ... }
        ///   ```
        /// - Error, on HTTP 3xx–5xx, no connection or an SDK failure:
        ///   ```json
        ///   { "status": "ProtocolError", "errorMessage": "<string>", "errorId": "<string>", "httpStatusCode": "400" }
        ///   ```
        ///   A validation error has `status` and `validationMessages`; a redirect or no connection,
        ///   `httpStatusCode` (`"null"` without a connection) and `errorMessage`; an SDK failure,
        ///   `errorKey`, `errorName` and `errorMessage`. A 2xx body that is not UTF-8 gets
        ///   `{ "error": "Response body is not valid UTF-8" }`.
        case syncOperation

        // MARK: JS → Native: Navigation, Settings & Permissions

        /// Opens a URL outside the page.
        ///
        /// An `http` or `https` URL opens in another app that claims it as a universal link, otherwise in
        /// an in-app Safari sheet; a link to this app's own universal-link domain opens in the sheet too.
        /// Any other scheme (`tel:`, `mailto:`, deep links) goes to the system. The answer comes once the
        /// URL is open.
        ///
        /// - Payload:
        ///   ```json
        ///   { "url": "https://example.com/product/123" }
        ///   ```
        /// - Response:
        ///   ```json
        ///   { "success": true }
        ///   ```
        /// - Errors: `invalid_payload` (no `url`), `invalid_url` (does not parse), `open_failed` (the system
        ///   did not open it, or no screen can present Safari), `not_visible` (a block page off screen).
        case openLink

        /// Opens the app's settings in the Settings app.
        ///
        /// `notifications` opens the app's notification settings (on iOS 15 and earlier, the app's
        /// settings) and always answers `success`. `application` opens the app's settings.
        ///
        /// - Payload:
        ///   ```json
        ///   { "target": "notifications" | "application" }
        ///   ```
        /// - Response:
        ///   ```json
        ///   { "success": true }
        ///   ```
        /// - Errors: `invalid_payload` (no `target`), `unsupported_value` (another target), `open_failed`
        ///   (the system did not open the `application` settings), `not_visible` (a block page off screen).
        case settingsOpen = "settings.open"

        /// Requests a device permission; only `pushNotifications` is supported.
        ///
        /// The system dialog appears only while the user has not decided yet; otherwise the current
        /// status comes back. Provisional and ephemeral authorization count as `"granted"`. After
        /// `"denied"` with `"dialogShown": false`, only Settings can change it: see ``settingsOpen``.
        ///
        /// - Payload:
        ///   ```json
        ///   { "type": "pushNotifications" }
        ///   ```
        /// - Response:
        ///   ```json
        ///   { "result": "granted" | "denied", "dialogShown": true | false }
        ///   ```
        /// - Errors: `invalid_payload` (no `type`), `unsupported_value` (another type), `permission_failed`
        ///   (the request failed), `not_visible` (a block page off screen).
        case permissionRequest = "permission.request"

        // MARK: JS → Native: Local State

        /// Reads values from the on-device key-value storage shared by all pages of the app.
        ///
        /// An empty or missing `data` list returns every stored value. A requested key that is not
        /// stored comes back as `null`. Values are strings.
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
        /// - Errors: `invalid_payload` (the payload is not a JSON object).
        case localStateGet = "localState.get"

        /// Writes values to the on-device key-value storage.
        ///
        /// A `null` value deletes the key; a value that is not a string is stored as its JSON text.
        /// Other open pages get ``localStateChanged``.
        ///
        /// - Payload:
        ///   ```json
        ///   { "data": { "key1": "value1", "key2": null } }
        ///   ```
        /// - Response: only the written keys, as stored, with the current version:
        ///   ```json
        ///   { "data": { "key1": "value1", "key2": null }, "version": 1 }
        ///   ```
        /// - Errors: `invalid_payload` (`data` is not an object).
        case localStateSet = "localState.set"

        /// Sets the storage version and writes values.
        ///
        /// The version is overwritten, not compared. Values are written as by ``localStateSet``, but
        /// other pages are not told.
        ///
        /// - Payload:
        ///   ```json
        ///   { "data": { "key1": "defaultValue1" }, "version": 1 }
        ///   ```
        /// - Response: only the written keys, with the new version:
        ///   ```json
        ///   { "data": { "key1": "defaultValue1" }, "version": 1 }
        ///   ```
        /// - Errors: `invalid_payload` (`data` is not an object, or `version` is not a positive integer).
        case localStateInit = "localState.init"

        // MARK: JS → Native: Haptic

        /// Plays haptic feedback.
        ///
        /// Answers `success` even when nothing plays: an invalid pattern, or a pattern on a device without
        /// Core Haptics or on iOS 12. A missing or unknown `type` plays `selection`; a missing or unknown
        /// `style` plays `medium` for impact and `success` for notification. On iOS 12, `"soft"` plays as
        /// `"light"` and `"rigid"` as `"heavy"`.
        ///
        /// **Selection** — light tick (e.g. scrolling a picker):
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
        /// **Pattern** — events at `time` ms from the start, each `duration` ms long (0 for a tap), with
        /// `intensity` and `sharpness` from 0 to 1; missing fields default to 0, 0, 1 and 0.5. Up to 128
        /// events, each at most 5 s long, all within 30 s. A new pattern stops the one playing.
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
        /// - Errors: `not_visible` (a block page off screen).
        case haptic

        // MARK: JS → Native: Motion

        /// Starts reporting motion gestures through ``motionEvent``, replacing the previous subscription.
        ///
        /// Unknown gesture names are ignored. `shake` is reported only on overlays: a block page can
        /// subscribe but never gets it. While `shake` is on, the system "Undo Typing" alert is off.
        /// Reporting pauses while the app is in the background.
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
        /// - Errors: also `invalid_payload` (no non-empty list of names), `unsupported_value` (no known
        ///   name), `not_visible` (a block page off screen).
        case motionStart = "motion.start"

        /// Stops all motion reporting and restores the app's own "Undo Typing" setting.
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
        /// **Shake** — the device was shaken (overlays only):
        /// ```json
        /// { "gesture": "shake" }
        /// ```
        ///
        /// **Flip** — the device moved to another of six positions: `faceUp`, `faceDown`, `portrait`,
        /// `portraitUpsideDown`, `landscapeLeft`, `landscapeRight`:
        /// ```json
        /// { "gesture": "flip", "from": "portrait", "to": "faceDown" }
        /// ```
        ///
        /// > Note: Flip fires on every change of position, but not for the position at start. Filter by
        /// > `to` to catch a target position (e.g. `to == "faceDown"`).
        case motionEvent = "motion.event"
        
        // MARK: Native → JS: Navigation

        /// Reports a link tap or form submission that tried to navigate the page; the SDK cancels the
        /// navigation and sends its URL.
        ///
        /// - Payload:
        ///   ```json
        ///   { "url": "<string>" }
        ///   ```
        case navigationIntercepted

        // MARK: JS → Native: Embedded pages

        /// Asks which of the listed in-apps the page may show.
        ///
        /// Ids are matched exactly as the config spells them; ids that are not strings are skipped. The
        /// SDK answers once it has the in-app config and has fetched the data their targeting needs,
        /// which can take a network request; with no config within 30 s, it answers an empty list.
        ///
        /// - Payload:
        ///   ```json
        ///   { "inappIds": ["<string>", "..."] }
        ///   ```
        /// - Response: the ids that may be shown, in any order:
        ///   ```json
        ///   { "inappIds": ["<string>", "..."] }
        ///   ```
        /// - Errors: `invalid_payload` (no `inappIds` list).
        case filterShowableInapps

        /// Reports how many items the page rendered: once per load and once after each
        /// ``initDataUpdated`` it applies.
        ///
        /// A positive count shows the block; zero means the page has nothing to show. On an overlay
        /// it is answered and ignored.
        ///
        /// - Payload:
        ///   ```json
        ///   { "count": <int> }
        ///   ```
        /// - Response:
        ///   ```json
        ///   { "success": true }
        ///   ```
        /// - Errors: `invalid_payload` (`count` is not a whole number of zero or more), which also fails the
        ///   block unless the page has already sent a positive count for this load or `initDataUpdated`.
        case contentRendered

        /// Shows an in-app over the screen by id, from a block page or an overlay.
        ///
        /// The id is matched exactly as the config spells it. `params` is optional; its keys go into the
        /// shown in-app's start data (see ``ready``) over the in-app's own params. An overlay that asks is
        /// closed by the new in-app and gets no answer; one closed before the show opens nothing.
        ///
        /// - Payload:
        ///   ```json
        ///   { "inappId": "<string>", "params": { } }
        ///   ```
        /// - Response, once the in-app is on screen:
        ///   ```json
        ///   { "success": true }
        ///   ```
        /// - Errors: `invalid_payload` (no `inappId`), `unknown_inapp` (after waiting up to 30 s for the
        ///   config: no in-app with this id, none that can be shown over the screen, or its images failed
        ///   to load), `show_failed` (the app is in the background or the in-app failed to appear),
        ///   `not_visible` (a block page off screen, or leaving it before the show).
        case showInApp

        // MARK: Native → JS: Embedded pages

        /// Sends a block page new start data without reloading it.
        ///
        /// Block pages only. The payload is the full start data, not a diff. Only a `response` confirms
        /// it: with no confirmation after 7 s on screen, the SDK may rebuild the page.
        ///
        /// - Payload: the same JSON as the ``ready`` response.
        /// - Response:
        ///   ```json
        ///   { "success": true }
        ///   ```
        ///   or, when the payload cannot be used:
        ///   ```json
        ///   { "error": "<string>" }
        ///   ```
        case initDataUpdated

        /// Tells a page that another page wrote through ``localStateSet``.
        ///
        /// Sent to every other open page that has sent ``ready``, overlays included.
        ///
        /// - Payload: the ``localStateSet`` response; `null` means the key was deleted.
        ///   ```json
        ///   { "data": { "<key>": "<string>" }, "version": <int> }
        ///   ```
        /// - Response:
        ///   ```json
        ///   { "success": true }
        ///   ```
        ///   or, when the payload cannot be used:
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
