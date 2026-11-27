//
//  PushDeliveryConfirmationHeaders.swift
//  Mindbox
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

enum PushDeliveryConfirmationHeaders {
    static func make(utilitiesFetcher: UtilitiesFetcher) -> [String: String] {
        [
            "Mindbox-Integration": "iOS-SDK",
            "Mindbox-Integration-Version": utilitiesFetcher.sdkVersion ?? "unknown",
            "User-Agent": SDKUserAgent.build(utilitiesFetcher: utilitiesFetcher),
            "Content-Type": "application/json; charset=utf-8"
        ]
    }
}
