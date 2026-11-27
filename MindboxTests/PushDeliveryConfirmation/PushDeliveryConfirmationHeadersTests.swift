//
//  PushDeliveryConfirmationHeadersTests.swift
//  MindboxTests
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
@testable import Mindbox

@Suite("PushDeliveryConfirmationHeaders")
struct PushDeliveryConfirmationHeadersTests {

    private struct StubUtilitiesFetcher: UtilitiesFetcher {
        var appVerson: String? { "3.1.4" }
        var sdkVersion: String? { "9.9.9" }
        var hostApplicationName: String? { "cloud.Mindbox.Host" }
        var applicationGroupIdentifier: String { "" }
        func generateDeviceUUID() -> String { UUID().uuidString }
    }

    @Test("Acceptance 2-4: the four headers match the SDK session")
    func headersMatchTheSDKSession() {
        let fetcher = StubUtilitiesFetcher()

        let headers = PushDeliveryConfirmationHeaders.make(utilitiesFetcher: fetcher)

        #expect(headers == [
            "Mindbox-Integration": "iOS-SDK",
            "Mindbox-Integration-Version": "9.9.9",
            "User-Agent": SDKUserAgent.build(utilitiesFetcher: fetcher),
            "Content-Type": "application/json; charset=utf-8"
        ])
        #expect(headers["User-Agent"]?.isEmpty == false)
    }

    @Test("Unknown SDK version falls back to unknown")
    func unknownSDKVersion() {
        struct NoVersionFetcher: UtilitiesFetcher {
            var appVerson: String? { nil }
            var sdkVersion: String? { nil }
            var hostApplicationName: String? { nil }
            var applicationGroupIdentifier: String { "" }
            func generateDeviceUUID() -> String { UUID().uuidString }
        }

        let headers = PushDeliveryConfirmationHeaders.make(utilitiesFetcher: NoVersionFetcher())

        #expect(headers["Mindbox-Integration-Version"] == "unknown")
    }
}
