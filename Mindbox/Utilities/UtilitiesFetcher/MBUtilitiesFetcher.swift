//
//  FetchUtilities.swift
//  Mindbox
//
//  Created by Mikhail Barilov on 20.01.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation
import AdSupport
import AppTrackingTransparency
import UIKit.UIDevice
#if SWIFT_PACKAGE
import SDKVersionProvider
#endif
import MindboxLogger

class MBUtilitiesFetcher: UtilitiesFetcher {

    private let appBundle: Bundle = {
        var bundle: Bundle = .main
        prepareBundle(&bundle)
        return bundle
    }()

    private let sdkBundle: Bundle = {
        var bundle = BundleToken.bundle
        prepareBundle(&bundle)
        return bundle
    }()

    /// Identifier of the shared App Group container used for the SDK's persistent
    /// storage (the events database and the `UserDefaults` suite).
    ///
    /// Returns an empty string when the host bundle identifier is missing or the
    /// App Group container is unavailable, so the SDK can fall back to local
    /// storage instead of crashing the host process (see issue #705).
    ///
    /// The SDK must never crash the host over this — not even in Debug. Automated
    /// device farms run Debug builds on real devices and frequently lack a
    /// configured App Group (signing/capability is easy to forget for test builds),
    /// so any trap (fatalError/assertionFailure/precondition) would break exactly
    /// the automated-testing scenario issue #705 is about. The misconfiguration is
    /// surfaced as a `.fault` log instead, on every platform.
    var applicationGroupIdentifier: String {
        guard let hostApplicationName = hostApplicationName else {
            Logger.common(message: "[MBUtilitiesFetcher] Host application bundle identifier is unavailable", level: .fault, category: .general)
            return ""
        }
        let identifier = "group.cloud.Mindbox.\(hostApplicationName)"
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) != nil else {
            let message = "App Group '\(identifier)' container is unavailable. "
                + "Enable the App Group capability with this exact value on every target (app + extensions). "
                + "See https://developers.mindbox.ru/docs/ios-sdk-initialization"
            Logger.common(message: message, level: .fault, category: .general)
            return ""
        }
        return identifier
    }

    init() {}

    private static func prepareBundle(_ bundle: inout Bundle) {
        if Bundle.main.bundleURL.pathExtension == "appex" {
            // Peel off two directory levels - MY_APP.app/PlugIns/MY_APP_EXTENSION.appex
            let url = bundle.bundleURL.deletingLastPathComponent().deletingLastPathComponent()
            if let otherBundle = Bundle(url: url) {
                bundle = otherBundle
            }
        }
    }

    var appVerson: String? {
        appBundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }

    var sdkVersion: String? {
        SDKVersionProvider.sdkVersion
    }

    var hostApplicationName: String? {
        appBundle.bundleIdentifier
    }

    func getDeviceUUID(completion: @escaping (String) -> Void) {
        if let uuid = IDFAFetcher().fetch() {
            Logger.common(message: "[MBUtilitiesFetcher] IDFAFetcher uuid:\(uuid.uuidString)", level: .default, category: .general)
            completion(uuid.uuidString)
        } else {
            IDFVFetcher().fetch(tryCount: 3) { uuid in
                if let uuid = uuid {
                    Logger.common(message: "[MBUtilitiesFetcher] IDFVFetcher uuid:\(uuid.uuidString)", level: .default, category: .general)
                    completion(uuid.uuidString)
                } else {
                    let uuid = UUID()
                    completion(uuid.uuidString)
                    Logger.common(message: "[MBUtilitiesFetcher] Generated uuid:\(uuid.uuidString)", level: .default, category: .general)
                }
            }
        }
    }
}

private final class BundleToken {
    static let bundle: Bundle = {
    #if SWIFT_PACKAGE
        return Bundle.module
    #else
        return Bundle(for: BundleToken.self)
    #endif
    }()
}
