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
