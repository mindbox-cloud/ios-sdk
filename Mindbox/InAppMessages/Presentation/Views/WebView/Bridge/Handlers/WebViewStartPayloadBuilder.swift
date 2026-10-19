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

struct WebViewStartPayloadBuilder {

    let contentId: String

    let operation: (name: String, body: String)?

    let customParams: [String: JSONValue]?

    let insetsSource: UIView?

    let logError: WebViewLogError

    static func mergedParams(config: [String: JSONValue],
                             fromCaller: [String: JSONValue]?) -> [String: JSONValue] {
        guard let fromCaller else { return config }

        return config.merging(fromCaller) { _, caller in caller }
    }

    func build(_ completion: @escaping (JSONValue) -> Void) {
        let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
        let systemInfoProvider = DI.injectOrFail(SystemInfoProvider.self)

        systemInfoProvider.getGrantedPermissions { permissions in
            var params = self.baseParams(persistenceStorage: persistenceStorage)
            self.addSystemInfo(to: &params, systemInfoProvider: systemInfoProvider, permissions: permissions)
            self.mergeCustomParams(into: &params)
            self.addOperationParams(to: &params)
            self.addTrackVisitParams(to: &params)

            completion(self.serialize(params))
        }
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

    func addSystemInfo(to params: inout [String: Any],
                       systemInfoProvider: SystemInfoProvider,
                       permissions: [String: PermissionStatus]) {
        params.merge(systemInfoProvider.getBasicSystemInfo()) { _, new in new }

        let insets = systemInfoProvider.getSafeAreaInsets(from: insetsSource)
        params[PayloadKey.Insets.key] = [
            PayloadKey.Insets.top: insets.top,
            PayloadKey.Insets.left: insets.left,
            PayloadKey.Insets.bottom: insets.bottom,
            PayloadKey.Insets.right: insets.right
        ]

        params[PayloadKey.permissions] = permissions.mapValues { $0.toDictionary() }
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

    func serialize(_ params: [String: Any]) -> JSONValue {
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
