//
//  SDKUserAgent.swift
//  Mindbox
//
//  Created by Sergei Semko on 06.07.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

/// One User-Agent for every SDK surface — API requests and WebView `applicationName` alike.
/// The backend slices traffic by this string, so transports must not drift apart. All
/// inputs are static per app run, which also keeps a prewarmed WebView indistinguishable
/// from a per-show one.
enum SDKUserAgent {
    static func build(utilitiesFetcher: UtilitiesFetcher = DI.injectOrFail(UtilitiesFetcher.self)) -> String {
        let sdkVersion = utilitiesFetcher.sdkVersion ?? "unknown"
        let appVersion = utilitiesFetcher.appVerson ?? "unknown"
        let appName = utilitiesFetcher.hostApplicationName ?? "unknown"

        return "mindbox.sdk/\(sdkVersion) (\(DeviceModelHelper.os) \(DeviceModelHelper.iOSVersion); \(DeviceModelHelper.model)) \(appName)/\(appVersion)"
    }
}
