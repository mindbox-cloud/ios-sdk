//
//  PushDeliveryConfirmationHeaders.swift
//  MindboxNotifications
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import UIKit.UIDevice
#if SWIFT_PACKAGE
import SDKVersionProvider
#endif

enum PushDeliveryConfirmationHeaders {

    static func make(hostBundle: Bundle = hostApplicationBundle()) -> [String: String] {
        let sdkVersion = SDKVersionProvider.sdkVersion
        return [
            "Mindbox-Integration": "iOS-SDK",
            "Mindbox-Integration-Version": sdkVersion,
            "User-Agent": userAgent(sdkVersion: sdkVersion, hostBundle: hostBundle),
            "Content-Type": "application/json; charset=utf-8"
        ]
    }

    static func userAgent(sdkVersion: String, hostBundle: Bundle) -> String {
        let appName = hostBundle.bundleIdentifier ?? "unknown"
        let appVersion = hostBundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let device = UIDevice.current
        return "mindbox.sdk/\(sdkVersion) (\(device.systemName) \(device.systemVersion); \(deviceModel)) \(appName)/\(appVersion)"
    }

    static func hostApplicationBundle(main: Bundle = .main) -> Bundle {
        guard main.bundleURL.pathExtension == "appex" else {
            return main
        }
        let applicationURL = main.bundleURL.deletingLastPathComponent().deletingLastPathComponent()
        return Bundle(url: applicationURL) ?? main
    }

    static let deviceModel: String = {
        var systemInfo = utsname()
        uname(&systemInfo)
        return Mirror(reflecting: systemInfo.machine).children.reduce(into: "") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            identifier.append(Character(UnicodeScalar(UInt8(value))))
        }
    }()
}
