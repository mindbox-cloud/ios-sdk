//
//  WebViewStartPayloadBuilder.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit
import MindboxLogger

private enum PayloadKey {
    static let sdkVersion = "sdkVersion"
    static let sdkVersionNumeric = "sdkVersionNumeric"
    static let endpointId = "endpointId"
    static let deviceUuid = "deviceUUID"
    static let userVisitCount = "userVisitCount"

    static let inappId = "inappId"
    static let operationName = "operationName"
    static let operationBody = "operationBody"

    static let trackVisitSource = "trackVisitSource"
    static let trackVisitRequestUrl = "trackVisitRequestUrl"

    static let firstInitializationDateTime = "firstInitializationDateTime"

    static let permissions = "permissions"
    static let localStateVersion = "localStateVersion"

    enum Insets {
        static let key = "insets"
        static let top = "top"
        static let left = "left"
        static let bottom = "bottom"
        static let right = "right"
    }
}

/// Everything a page needs to configure itself, as answered to `ready`.
///
/// Built fresh each time rather than once per show: safe-area insets, granted permissions and
/// the visit counters are all snapshots, and a page asking again should be told what is true
/// now. That also makes it the same builder the config-update push can reuse.
///
/// > Note: the result is a JSON-encoded **string**, not an object — the bridge contract has JS
/// > calling `JSON.parse` on it.
struct WebViewStartPayloadBuilder {

    /// The in-app id for a popup, the block id for an embedded block.
    let contentId: String

    /// The operation that led to this show, when there was one.
    let operation: (name: String, body: String)?

    /// Whatever the content configuration carries for the page. Merged at the root.
    let customParams: [String: JSONValue]?

    /// The view the safe-area insets are measured from.
    let insetsSource: UIView?

    let logError: WebViewLogError

    /// The params a show is started with: what the caller asked for wins over what the configuration
    /// carries, and both win over the fields the SDK fills in — a direct call names what this show
    /// must carry, and neither the config nor the SDK can know it.
    static func mergedParams(config: [String: JSONValue],
                             fromCaller: [String: JSONValue]?) -> [String: JSONValue] {
        guard let fromCaller else { return config }

        return config.merging(fromCaller) { _, caller in caller }
    }

    func build() -> JSONValue {
        let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
        let systemInfoProvider = DI.injectOrFail(SystemInfoProvider.self)

        // The order is load-bearing: the configuration's own params are merged before the
        // operation and track-visit fields, which therefore win over a colliding key.
        var params = baseParams(persistenceStorage: persistenceStorage)
        addSystemInfo(to: &params, systemInfoProvider: systemInfoProvider)
        mergeCustomParams(into: &params)
        addOperationParams(to: &params)
        addTrackVisitParams(to: &params)

        return serialize(params)
    }
}

private extension WebViewStartPayloadBuilder {

    func baseParams(persistenceStorage: PersistenceStorage) -> [String: Any] {
        var params: [String: Any] = [
            PayloadKey.sdkVersion: Mindbox.shared.sdkVersion,
            PayloadKey.endpointId: persistenceStorage.configuration?.endpoint ?? "",
            PayloadKey.deviceUuid: persistenceStorage.deviceUUID ?? "",
            PayloadKey.userVisitCount: "\(persistenceStorage.userVisitCount ?? 0)",
            PayloadKey.sdkVersionNumeric: "\(Constants.Versions.sdkVersionNumeric)",
            PayloadKey.inappId: contentId,
            // Add localState version for WebView JS migration logic
            PayloadKey.localStateVersion: persistenceStorage.webViewLocalStateVersion ?? Constants.WebViewLocalState.defaultVersion
        ]

        if let firstInitDate = persistenceStorage.firstInitializationDateTime {
            params[PayloadKey.firstInitializationDateTime] = firstInitDate.toString(withFormat: .utc)
        }

        return params
    }

    func addOperationParams(to params: inout [String: Any]) {
        guard let operation else { return }
        params[PayloadKey.operationName] = operation.name
        params[PayloadKey.operationBody] = operation.body
    }

    func addSystemInfo(to params: inout [String: Any], systemInfoProvider: SystemInfoProvider) {
        params.merge(systemInfoProvider.getBasicSystemInfo()) { _, new in new }

        let insets = systemInfoProvider.getSafeAreaInsets(from: insetsSource)
        params[PayloadKey.Insets.key] = [
            PayloadKey.Insets.top: insets.top,
            PayloadKey.Insets.left: insets.left,
            PayloadKey.Insets.bottom: insets.bottom,
            PayloadKey.Insets.right: insets.right
        ]

        let permissions = systemInfoProvider.getGrantedPermissions()
        if !permissions.isEmpty {
            params[PayloadKey.permissions] = permissions.mapValues { $0.toDictionary() }
        }
    }

    func mergeCustomParams(into params: inout [String: Any]) {
        guard let customParams, !customParams.isEmpty else { return }

        for (key, value) in customParams {
            params[key] = value.anyValue ?? NSNull()
        }
    }

    func addTrackVisitParams(to params: inout [String: Any]) {
        guard let lastTrackVisit = SessionTemporaryStorage.shared.lastTrackVisit else { return }

        if let source = lastTrackVisit.source {
            params[PayloadKey.trackVisitSource] = source.rawValue
        }
        if let requestUrl = lastTrackVisit.requestUrl {
            params[PayloadKey.trackVisitRequestUrl] = requestUrl
        }
    }

    /// An empty object rather than a throw: a page that gets `{}` reports its own failure, while
    /// a missing answer leaves it waiting on an id nothing will ever close.
    func serialize(_ params: [String: Any]) -> JSONValue {
        // Asked first because the failure below cannot be caught: `JSONSerialization` raises an
        // Objective-C exception for a NaN or an infinity rather than throwing a Swift error, so
        // the `catch` never runs and the host app goes down instead. Values reaching here are
        // decoded from JSON today, which cannot express either — but this is the payload every
        // surface is answered with, and a crash is a steep price for that assumption holding.
        guard JSONSerialization.isValidJSONObject(params) else {
            logError("[WebView] Start payload contains a value JSON cannot represent")
            return .string("{}")
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: params, options: [])
            guard let jsonString = String(bytes: data, encoding: .utf8) else {
                logError("[WebView] Failed to convert JSON data to UTF-8 string")
                return .string("{}")
            }
            return .string(jsonString)
        } catch {
            logError("[WebView] Failed to encode start payload to JSON string: \(error)")
            return .string("{}")
        }
    }
}
