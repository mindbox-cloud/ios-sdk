//
//  TEmpFetcher.swift
//  MindboxLogger
//
//  Created by Akylbek Utekeshev on 07.02.2023.
//  Copyright © 2023 Mikhail Barilov. All rights reserved.
//

import Foundation

class MBLoggerUtilitiesFetcher {

    let appBundle: Bundle = {
        var bundle: Bundle = .main
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

    var hostApplicationName: String? {
        appBundle.bundleIdentifier
    }
}
