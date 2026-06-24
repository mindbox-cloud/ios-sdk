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

    /// Identifier of the shared App Group container the logger persists its
    /// database in, or `nil` when no shared container is available.
    ///
    /// Returns `nil` when the host bundle identifier is missing or the App Group
    /// container is unavailable (a missing, misconfigured, or unprovisioned capability).
    /// A `nil` identifier makes `LoggerDatabaseLoader` fall back to the app's local
    /// (caches) store, so
    /// the logger keeps working — just not in the shared container — instead of
    /// being disabled. This must never `fatalError`: the SDK must not bring down
    /// its host over an unavailable container, on simulator or device (issue #705).
    var applicationGroupIdentifier: String? {
        guard let hostApplicationName = hostApplicationName else {
            return nil
        }
        let identifier = "group.cloud.Mindbox.\(hostApplicationName)"
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) != nil else {
            return nil
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
