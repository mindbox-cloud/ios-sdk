//
//  WebViewNoCacheRetryPolicyTests.swift
//  MindboxTests
//
//  Created by sozinov on 24.07.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
@testable import Mindbox

/// Mirror of the Android SDK's `WebViewNoCacheRetryPolicyTest`.
@Suite("WebView no-cache retry policy", .tags(.webView))
struct WebViewNoCacheRetryPolicyTests {

    private let trackerURL = "https://api.example.com/scripts/v1/tracker.js?v=1.0.31"

    private func policy(cacheEnabled: Bool = true) -> WebViewNoCacheRetryPolicy {
        WebViewNoCacheRetryPolicy { cacheEnabled }
    }

    @Test
    func grantsARetryForAScript404BeforeInit() {
        let policy = policy()

        #expect(policy.onHTTPError(url: trackerURL, status: 404, hasReceivedInit: false))
        #expect(policy.hasRetried)
        #expect(policy.lastHTTPErrorDetail == "HTTP 404 for \(trackerURL)")
    }

    @Test
    func grantsARetryForAServerErrorOnAScript() {
        #expect(policy().onHTTPError(url: "https://cdn.test/main.js", status: 503, hasReceivedInit: false))
    }

    @Test
    func grantsOnlyOneRetryPerShowSession() {
        let policy = policy()

        #expect(policy.onHTTPError(url: trackerURL, status: 404, hasReceivedInit: false))
        #expect(!policy.onHTTPError(url: trackerURL, status: 404, hasReceivedInit: false))
        // The later error still refreshes the telemetry detail.
        #expect(!policy.onHTTPError(url: "https://cdn.test/other.js", status: 500, hasReceivedInit: false))
        #expect(policy.lastHTTPErrorDetail == "HTTP 500 for https://cdn.test/other.js")
    }

    @Test
    func doesNotRetryAfterTheRuntimeInitialized() {
        let policy = policy()

        #expect(!policy.onHTTPError(url: trackerURL, status: 404, hasReceivedInit: true))
        #expect(!policy.hasRetried)
        // A live in-app must not be reloaded, but the error is still worth remembering.
        #expect(policy.lastHTTPErrorDetail == "HTTP 404 for \(trackerURL)")
    }

    @Test
    func doesNotRetryNonScriptResources() {
        let policy = policy()

        #expect(!policy.onHTTPError(url: "https://cdn.test/banner.png", status: 404, hasReceivedInit: false))
        #expect(!policy.onHTTPError(
            url: "https://personalization-speedtest.g.mindbox.ru/client-stats?x=1",
            status: 404,
            hasReceivedInit: false
        ))
        #expect(policy.lastHTTPErrorDetail == nil)
    }

    @Test
    func doesNotRetryOnStatusesBelow400() {
        let policy = policy()

        #expect(!policy.onHTTPError(url: trackerURL, status: 302, hasReceivedInit: false))
        #expect(!policy.onHTTPError(url: trackerURL, status: 200, hasReceivedInit: false))
        #expect(policy.lastHTTPErrorDetail == nil)
        #expect(!policy.hasRetried)
    }

    /// Platform difference vs Android (spec D1): the JS detector can only say "the script
    /// failed" on WebKit without `responseStatus` — a nil status on a script grants the retry.
    @Test
    func nilStatusOnAScriptGrantsTheRetry() {
        let policy = policy()

        #expect(policy.onHTTPError(url: trackerURL, status: nil, hasReceivedInit: false))
        #expect(policy.lastHTTPErrorDetail == "HTTP ? for \(trackerURL)")
    }

    @Test
    func retriesOnTheBoundaryStatus400() {
        #expect(policy().onHTTPError(url: trackerURL, status: 400, hasReceivedInit: false))
    }

    @Test
    func cacheFeatureOffBlocksTheRetryButKeepsTheTelemetryDetail() {
        let policy = policy(cacheEnabled: false)

        #expect(!policy.onHTTPError(url: trackerURL, status: 404, hasReceivedInit: false))
        #expect(!policy.hasRetried)
        #expect(policy.lastHTTPErrorDetail == "HTTP 404 for \(trackerURL)")
    }

    @Test
    func cacheGateIsConsultedOnlyWhenARetryWouldActuallyFire() {
        var consulted = 0
        let policy = WebViewNoCacheRetryPolicy {
            consulted += 1
            return true
        }

        _ = policy.onHTTPError(url: "https://cdn.test/banner.png", status: 404, hasReceivedInit: false)
        #expect(consulted == 0)

        _ = policy.onHTTPError(url: trackerURL, status: 404, hasReceivedInit: true)
        #expect(consulted == 0)

        _ = policy.onHTTPError(url: trackerURL, status: 404, hasReceivedInit: false)
        #expect(consulted == 1)
    }
}
