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

    var applicationGroupIdentifier: String {
        if let groups = Bundle.main.object(forInfoDictionaryKey: "com.apple.security.application-groups") as? [String],
            let first = groups.first,
               !first.isEmpty,
               FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: first) != nil {
                return first
            }
            if let explicit = Bundle.main.object(forInfoDictionaryKey: "MindboxApplicationGroup") as? String,
               !explicit.isEmpty,
               FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: explicit) != nil {
            return explicit
        }
        guard let hostApplicationName = hostApplicationName else {
            fatalError("CFBundleShortVersionString not found for host app")
        }
        let identifier = "group.cloud.Mindbox.\(hostApplicationName)"
        let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
        guard url != nil else {
            #if targetEnvironment(simulator)
            return ""
            #else
            let message = "AppGroup for \(hostApplicationName) not found. Add AppGroup with value: \(identifier)"
            Logger.common(message: message, level: .fault, category: .general)
            fatalError(message)
            #endif
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
