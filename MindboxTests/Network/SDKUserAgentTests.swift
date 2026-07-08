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

    /// Pins the UA layout `mindbox.sdk/<sdk> (<os> <ver>; <model>) <app>/<appVer>` so a
    /// refactor can't reorder the segments: the backend slices traffic by this string, and
    /// the network layer and the WebView share this single builder.
    @Test
    func buildKeepsSegmentOrderAndFormat() {
        let fetcher = StubUtilitiesFetcher(sdkVersion: "9.9.9", appVerson: "1.2.3", hostApplicationName: "com.test.app")
        let ua = SDKUserAgent.build(utilitiesFetcher: fetcher)

        // sdk token first, app/appVer last — a reordering breaks the prefix/suffix.
        #expect(ua.hasPrefix("mindbox.sdk/9.9.9 ("))
        #expect(ua.hasSuffix(") com.test.app/1.2.3"))
        // The device segment "(os ver; model)" sits between them.
        #expect(ua.contains("; "))
    }

    /// Missing bundle metadata falls back to "unknown" in every slot — not the legacy
    /// "unknow" typo, and not an empty token.
    @Test
    func buildFallsBackToUnknown() {
        let fetcher = StubUtilitiesFetcher(sdkVersion: nil, appVerson: nil, hostApplicationName: nil)
        let ua = SDKUserAgent.build(utilitiesFetcher: fetcher)

        #expect(ua.hasPrefix("mindbox.sdk/unknown ("))
        #expect(ua.hasSuffix(") unknown/unknown"))
    }
}
