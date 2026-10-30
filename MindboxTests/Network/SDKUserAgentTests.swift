//
//  SDKUserAgentTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 08.07.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
@testable import Mindbox

@Suite("SDK User-Agent builder", .tags(.userAgent))
struct SDKUserAgentTests {

    private struct StubUtilitiesFetcher: UtilitiesFetcher {
        var sdkVersion: String?
        var appVerson: String?
        var hostApplicationName: String?
        var applicationGroupIdentifier = "group.stub"
        func getDeviceUUID(completion: @escaping (String) -> Void) { completion("") }
    }

    @Test("Keeps the segment order the backend slices traffic by: mindbox.sdk/<sdk> (<os> <ver>; <model>) <app>/<appVer>")
    func buildKeepsSegmentOrderAndFormat() {
        let fetcher = StubUtilitiesFetcher(sdkVersion: "9.9.9", appVerson: "1.2.3", hostApplicationName: "com.test.app")
        let ua = SDKUserAgent.build(utilitiesFetcher: fetcher)

        #expect(ua.hasPrefix("mindbox.sdk/9.9.9 ("))
        #expect(ua.hasSuffix(") com.test.app/1.2.3"))
        #expect(ua.contains("; "))
    }

    @Test
    func buildFallsBackToUnknown() {
        let fetcher = StubUtilitiesFetcher(sdkVersion: nil, appVerson: nil, hostApplicationName: nil)
        let ua = SDKUserAgent.build(utilitiesFetcher: fetcher)

        #expect(ua.hasPrefix("mindbox.sdk/unknown ("))
        #expect(ua.hasSuffix(") unknown/unknown"))
    }
}
