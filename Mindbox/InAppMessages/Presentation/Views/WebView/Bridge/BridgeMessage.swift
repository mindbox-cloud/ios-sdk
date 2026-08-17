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

    /// Merges in-app tags into the root of a custom operation `body`.
    ///
    /// - No `tags` key (or `null`) in `body` → sets it to the tags object.
    /// - `tags` already an object → adds only missing keys; existing client keys win.
    /// - `tags` present but not an object (string/array/etc.) → left untouched.
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

@_spi(Internal)
public struct BridgeMessage: Codable {
    public enum MessageType: String, Codable {
        case request
        case response
        case error
    }

    enum Action: String, CaseIterable {

        // MARK: JS → Native: Lifecycle

        /// JS requests to close the in-app and trigger dismiss callback.
        ///
        /// Stops haptic patterns and motion monitoring. Triggers ``WebViewAction/onClose()``.
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

        /// JS signals that the in-app content is initialized.
        ///
        /// Prepares the haptic engine for upcoming feedback. Triggers ``WebViewAction/onInit()``.
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

        /// JS reports a user click with navigation intent.
        ///
        /// The raw payload string is forwarded as-is to ``WebViewAction/onCompleted(data:)``
        /// without parsing or validation on the native side.
        ///
        /// - Payload (typical):
        ///   ```json
        ///   { "$type": "redirectUrl", "value": "https://example.com", "intentPayload": "promo123" }
        ///   ```
        /// - Response:
        ///   ```json
        ///   { "success": true }
        ///   ```
        case click

        /// JS requests to hide the WebView without fully closing it.
        ///
        /// Triggers ``WebViewAction/onHide()``.
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

        /// JS confirms the bridge is ready to receive messages.
        ///
        /// Native responds with a JSON string containing all init parameters
        /// needed by the web content to configure itself.
        ///
        /// - Payload:
        ///   ```json
        ///   {}
        ///   ```
        /// - Response: JSON string with the following fields:
        ///   ```json
        ///   {
        ///     "sdkVersion": "2.15.0",
        ///     "sdkVersionNumeric": "11",
        ///     "endpointId": "my-app-endpoint",
        ///     "deviceUUID": "A1B2C3D4-E5F6-7890-ABCD-EF1234567890",
        ///     "userVisitCount": "41",
        ///     "inAppId": "65f3a8b9-2c4d-4e5f-a6b7-c8d9e0f12345",
        ///     "firstInitializationDateTime": "2025-01-15T10:30:00Z",
        ///     "localStateVersion": 1,
        ///     "operationName": "Inapp.Click",
        ///     "operationBody": "{\"inappId\":\"...\"}",
        ///     "trackVisitSource": "link",
        ///     "trackVisitRequestUrl": "https://example.com/page",
        ///     "permissions": {
        ///       "pushNotifications": { "granted": true }
        ///     },
        ///     "insets": { "top": 47, "left": 0, "bottom": 34, "right": 0 },
        ///     "theme": "light",
        ///     "platform": "ios",
        ///     "locale": "en_US",
        ///     "version": "1.2.3"
        ///   }
        ///   ```
        ///
        /// > Note: The response payload is a **JSON-encoded string**, not a raw object.
        /// > JS must parse it with `JSON.parse()` to access the fields.
        /// >
        /// > Fields `operationName`, `operationBody`, `trackVisitSource`,
        /// > `trackVisitRequestUrl`, `permissions`, `firstInitializationDateTime`,
        /// > `version` (app version) are optional and included only when available.
        /// > Custom params from in-app configuration are merged at root level.
        case ready

        // MARK: JS → Native: Info

        /// JS sends a message to native SDK logger.
        ///
        /// Handled by ``LogActionHandler``, which journals it under the host's own log category.
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

        /// JS triggers an asynchronous Mindbox operation (fire-and-forget).
        ///
        /// The operation is sent to the Mindbox backend.
        ///
        /// - Payload:
        ///   ```json
        ///   { "operation": "<string>", "body": { ... } }
        ///   ```
        /// - Response:
        ///   ```json
        ///   { "success": true }
        ///   ```
        case asyncOperation

        /// JS triggers a synchronous Mindbox operation and expects a response body.
        ///
        /// - Payload:
        ///   ```json
        ///   { "operation": "<string>", "body": { ... } }
        ///   ```
        /// - Response: operation response JSON from Mindbox backend
        case syncOperation

        // MARK: JS → Native: Navigation, Settings & Permissions

        /// JS requests to open a URL in an external handler.
        ///
        /// For `http`/`https` URLs: first tries to open as a universal link
        /// (another app that handles this domain). If no app claims it,
        /// falls back to in-app `SFSafariViewController`.
        ///
        /// For custom schemes (e.g. `tel:`, `mailto:`, deep links):
        /// opens via `UIApplication.open`.
        ///
        /// - Payload:
        ///   ```json
        ///   { "url": "https://example.com/product/123" }
        ///   ```
        /// - Response:
        ///   ```json
        ///   { "success": true }
        ///   ```
        case openLink

        /// JS requests to open device or app settings.
        ///
        /// - Payload:
        ///   ```json
        ///   { "target": "notifications" | "application" }
        ///   ```
        /// - Response:
        ///   ```json
        ///   { "success": true }
        ///   ```
        ///
        /// > Note: `"notifications"` opens system notification settings for the app.
        /// > `"application"` opens the app's page in Settings.
        case settingsOpen = "settings.open"

        /// JS requests a device permission.
        ///
        /// Currently only push notifications are supported.
        /// Shows the system permission dialog if status is `.notDetermined`,
        /// otherwise returns current authorization status without a dialog.
        ///
        /// - Payload:
        ///   ```json
        ///   { "type": "pushNotifications" }
        ///   ```
        /// - Response:
        ///   ```json
        ///   { "result": "granted" | "denied", "dialogShown": true | false }
        ///   ```
        ///
        /// > Note: If the user previously denied notifications, `"denied"` is returned
        /// > with `"dialogShown": false`. Use `settingsOpen` to redirect the user to Settings.
        case permissionRequest = "permission.request"

        // MARK: JS → Native: Local State

        /// JS retrieves saved values from on-device key-value storage.
        ///
        /// If `data` array is empty or omitted, **all** stored values are returned.
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
        ///   { "data": { "key1": "value1", "key2": "value2" }, "version": 1 }
        ///   ```
        case localStateGet = "localState.get"

        /// JS saves values to on-device key-value storage by key.
        ///
        /// - Payload:
        ///   ```json
        ///   { "data": { "key1": "value1", "key2": "value2" } }
        ///   ```
        /// - Response: echoes the saved keys with current version:
        ///   ```json
        ///   { "data": { "key1": "value1", "key2": "value2" }, "version": 1 }
        ///   ```
        ///
        /// > Note: Only the keys from the request are returned, not the full stored state.
        case localStateSet = "localState.set"

        /// JS initializes local state and updates schema version.
        ///
        /// Merges provided data into storage and sets the version number.
        /// Always applies data regardless of current version — version is overwritten, not compared.
        ///
        /// - Payload:
        ///   ```json
        ///   { "data": { "key1": "defaultValue1" }, "version": 1 }
        ///   ```
        /// - Response: echoes the initialized keys with the set version:
        ///   ```json
        ///   { "data": { "key1": "defaultValue1" }, "version": 1 }
        ///   ```
        ///
        /// > Note: Only the keys from the request are returned, not the full stored state.
        case localStateInit = "localState.init"

        // MARK: JS → Native: Haptic

        /// JS triggers haptic feedback.
        ///
        /// Four feedback types are supported:
        ///
        /// **Selection** — light tick (e.g. scrolling a picker):
        /// ```json
        /// { "type": "selection" }
        /// ```
        ///
        /// **Impact** — single tap with configurable intensity:
        /// ```json
        /// { "type": "impact", "style": "light" | "medium" | "heavy" | "soft" | "rigid" }
        /// ```
        ///
        /// **Notification** — system notification feedback:
        /// ```json
        /// { "type": "notification", "style": "success" | "warning" | "error" }
        /// ```
        ///
        /// **Custom pattern** — sequence of haptic events:
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
        ///
        /// > Note: `"soft"` and `"rigid"` impact styles require iOS 13+.
        /// > On older versions they fall back to `"light"` and `"heavy"` respectively.
        case haptic

        // MARK: JS → Native: Motion

        /// JS subscribes to motion gestures (shake, flip).
        ///
        /// Replaces any previous subscription. Starts device sensors as needed.
        ///
        /// - Payload:
        ///   ```json
        ///   { "gestures": ["shake", "flip"] }
        ///   ```
        /// - Response (all gestures available):
        ///   ```json
        ///   { "success": true }
        ///   ```
        /// - Response (some gestures unavailable, rest started):
        ///   ```json
        ///   { "success": true, "unavailable": ["flip"] }
        ///   ```
        /// - Error (all requested gestures unavailable):
        ///   ```json
        ///   { "error": "No sensors available for requested gestures: flip" }
        ///   ```
        ///
        /// > Note: When shake is active, the system "Undo Typing" alert is suppressed
        /// > via `applicationSupportsShakeToEdit`. The original setting is restored on stop.
        case motionStart = "motion.start"

        /// JS stops all motion gesture monitoring.
        ///
        /// Stops device sensors and restores `applicationSupportsShakeToEdit`.
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

        /// SDK notifies JS about a detected motion gesture.
        ///
        /// Fired for each gesture event while monitoring is active.
        ///
        /// **Shake** — device was shaken (system detection via `UIResponder.motionEnded`):
        /// ```json
        /// { "gesture": "shake" }
        /// ```
        ///
        /// **Flip** — device changed orientation (gravity-based, 6 positions):
        /// ```json
        /// { "gesture": "flip", "from": "portrait", "to": "faceDown" }
        /// ```
        ///
        /// Positions: `faceUp`, `faceDown`, `portrait`, `portraitUpsideDown`,
        /// `landscapeLeft`, `landscapeRight`.
        ///
        /// > Note: Flip fires on every position change. JS should filter
        /// > by `to` field to match the desired target (e.g. `to == "faceDown"`).
        case motionEvent = "motion.event"
        
        // MARK: Native → JS: Navigation

        /// SDK notifies JS about an intercepted main frame navigation.
        ///
        /// Fired when WKWebView attempts to navigate away from the in-app content.
        ///
        /// - Payload:
        ///   ```json
        ///   { "url": "<string>" }
        ///   ```
        case navigationIntercepted

        // MARK: JS → Native: Feeds
        //
        // A feed page renders a list of in-apps rather than one in-app, so it asks the SDK the things
        // only the SDK can answer and reports back what it drew.
        //
        // Beware of two spellings of one idea in this group: the bridge payloads say `inappId` and
        // `inappIds`, while an element of the feed's own list says `inAppId`, because that is the
        // config's spelling and the SDK forwards config params untouched. Neither side may be
        // "corrected" to match the other — both are silent when wrong.

        /// JS asks which of these in-apps it is allowed to render.
        ///
        /// Answering is the only place a feed's items are filtered: the page cannot see targeting, the
        /// A/B pool or what the frequency still allows. The page gives up after 3 seconds and renders an
        /// empty feed, so an unanswered request looks exactly like an empty one.
        ///
        /// > Important: the SDK does not race that deadline — it answers when the selection answers,
        /// > and what a late answer means is the page's call.
        ///
        /// - Payload:
        ///   ```json
        ///   { "inappIds": ["<string>", "..."] }
        ///   ```
        /// - Response: the subset that may be rendered, in any order:
        ///   ```json
        ///   { "inappIds": ["<string>", "..."] }
        ///   ```
        case checkInappsTargeting

        /// JS reports how many items it actually rendered, exactly once per load.
        ///
        /// This is what readiness means for a feed: a loaded document says nothing, and a count of zero
        /// is a legitimate "nothing to show" rather than a failure.
        ///
        /// The page does not wait for the confirmation, which does not make it optional — every request
        /// on this bridge is answered under the same id. A count that is not a whole non-negative
        /// number is refused with an error rather than rounded: rounding would decide the block's
        /// fate on the page's behalf.
        ///
        /// - Payload:
        ///   ```json
        ///   { "count": <int> }
        ///   ```
        /// - Response:
        ///   ```json
        ///   { "success": true }
        ///   ```
        case contentRendered

        /// JS asks to show one in-app from the feed, by id.
        ///
        /// `sourceInappId` is the in-app the tap came from — the feed itself. `params` is the feed's own
        /// catalogue entry for the tapped item, forwarded without listing its fields, so fields the
        /// config gains later reach the shown page by themselves.
        ///
        /// Showing is the SDK's business from here on: it merges `params` flat into the shown in-app's
        /// start payload, where an incoming key overwrites — the same semantics as the params of a
        /// webview layer. Not to be confused with ``click``, which happens inside an already open page.
        ///
        /// - Payload:
        ///   ```json
        ///   { "inappId": "<string>", "index": <int>, "sourceInappId": "<string>", "params": { } }
        ///   ```
        /// - Response:
        ///   ```json
        ///   { "success": true }
        ///   ```
        case showInApp

        // MARK: Native → JS: Feeds

        /// SDK hands JS fresh initialization data, without reloading the page.
        ///
        /// Sent when the config changed or an A/B verdict flipped. The payload has the same shape as the
        /// ``ready`` response, and the page always reacts the same way: it runs its whole load pipeline
        /// again. Pushes carry full state rather than deltas, which is what makes reacting idempotent.
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

        /// SDK tells JS that stored keys changed, so a page can repaint without being asked.
        ///
        /// Sent to every other live WebView when one of them writes through ``localStateSet``, as a
        /// separate request into each page's own channel — there is no page-to-page channel. It is a
        /// broadcast: the receiver picks out the keys it cares about and ignores the rest.
        ///
        /// - Payload: the same shape as the ``localStateSet`` response. A `null` value means the key is
        ///   gone.
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

        /// Actions that send their own bridge responses (no auto-response from dispatcher).
        ///
        /// The auto-response goes out before the handler runs, so a handler that refuses a non-deferred
        /// action sends a second envelope under the same id, and the page is expected to take the later
        /// one.
        var isDeferred: Bool {
            switch self {
            // Lifecycle
            case .ready:
                return true
            case .close, .`init`, .click, .hide, .log:
                return false

            // Answers for itself so a payload without a usable count is refused outright. The
            // blanket success would otherwise claim the SDK acted on a number it never got.
            case .contentRendered:
                return true

            // Both carry an answer the page acts on: one returns the ids that passed, the other
            // reports whether the show was accepted.
            case .checkInappsTargeting, .showInApp:
                return true

            // Operations
            case .asyncOperation, .syncOperation:
                return true

            // Navigation, Settings & Permissions
            case .openLink, .settingsOpen, .permissionRequest:
                return true

            // Local State
            case .localStateGet, .localStateSet, .localStateInit:
                return true

            // Haptic
            case .haptic:
                return true

            // Motion
            case .motionStart, .motionStop:
                return true

            // Native → JS: Motion
            case .motionEvent:
                return false

            // Native → JS: Navigation
            case .navigationIntercepted:
                return false

            // Native → JS: Feeds and storage
            case .initDataUpdated, .localStateChanged:
                return false
            }
        }

        static let deferredActions: Set<Action> = Set(allCases.filter(\.isDeferred))

        /// Actions that act on the user's behalf, and therefore must not run on a page nobody is
        /// looking at.
        ///
        /// An embedded block that left the window keeps its page alive, and that page still
        /// delivers whatever its `setTimeout` scheduled. Nothing the user did stands behind such a
        /// message, so anything that leaves the app, covers it, or reaches for the device has to be
        /// refused. Enforced by ``WebBridgeActionRegistry`` before dispatch, and again by the
        /// handlers that go on to wait — the page can leave the screen while they do.
        ///
        /// Every action listed here is also ``isDeferred``, and has to be: the refusal reaches the
        /// page as the answer to its request, while a non-deferred action was already answered
        /// `{success: true}` by the dispatcher before a handler ever saw it.
        var requiresUserPresence: Bool {
            switch self {
            // Leave the app or cover it — a Safari sheet, the settings screen, a permission
            // dialog — over whatever the user went to instead.
            case .openLink, .settingsOpen, .permissionRequest:
                return true

            // Felt rather than seen, which makes it worse: a block three screens down buzzing the
            // device gives the user nothing to trace it back to.
            case .haptic:
                return true

            // Takes the sensors on behalf of a page nobody sees. Stopping is always allowed —
            // giving the sensors back is not something done on the user's behalf.
            case .motionStart:
                return true

            // Opens a window, once it is implemented.
            case .showInApp:
                return true

            case .motionStop, .ready, .close, .`init`, .click, .hide, .log,
                 .contentRendered, .checkInappsTargeting,
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

    /// The payload as an object, whether JS sent it as a JSON string — the ordinary case,
    /// `"{\"data\":{...},\"version\":3}"` — or as an already-decoded object.
    ///
    /// `nil` means neither shape parsed, which is a malformed request rather than an empty one.
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

    /// The payload as the string a handler logs or forwards verbatim.
    ///
    /// JS sends it as a JSON string, so that is the ordinary case. A payload that arrived
    /// already decoded is re-encoded rather than described, so what a handler sees does not
    /// depend on which of the two shapes the page happened to send.
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

        // JS bridge protocol requires payload as a JSON string (JS does JSON.parse(message.payload))
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

        // JS generates lowercase UUIDs; Map lookup is case-sensitive
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
