//
//  WebViewNoCacheRetryPolicyTests.swift
//  MindboxTests
//
//  Created by sozinov on 24.07.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
@testable import Mindbox

@Suite("WebView no-cache retry policy", .tags(.webView))
struct WebViewNoCacheRetryPolicyTests {

    private let trackerURL = "https://api.example.com/scripts/v1/tracker.js?v=1.0.31"

    private func policy(cacheEnabled: Bool = true) -> WebViewNoCacheRetryPolicy {
        WebViewNoCacheRetryPolicy { cacheEnabled }
    }

    @Test
    func grantsARetryForAFailedScriptBeforeInit() {
        let policy = policy()

        #expect(policy.onHTTPError(url: trackerURL, hasReceivedInit: false))
        #expect(policy.hasRetried)
        #expect(policy.lastHTTPErrorDetail == "load failure (no HTTP status on WebKit) for \(trackerURL)")
    }

    @Test
    func successfulPurgeLatchesTheRetryForTheShowSession() {
        let policy = policy()

        #expect(policy.onHTTPError(url: trackerURL, hasReceivedInit: false))
        policy.notePurgeOutcome(didRemoveAnything: true)
        #expect(!policy.onHTTPError(url: trackerURL, hasReceivedInit: false))
        #expect(!policy.onHTTPError(url: "https://cdn.test/other.js", hasReceivedInit: false))
        #expect(policy.lastHTTPErrorDetail == "load failure (no HTTP status on WebKit) for https://cdn.test/other.js")
    }

    @Test
    func emptyPurgeAllowsExactlyOneMoreAttempt() {
        let policy = policy()

        #expect(policy.onHTTPError(url: trackerURL, hasReceivedInit: false))
        policy.notePurgeOutcome(didRemoveAnything: false)
        #expect(policy.onHTTPError(url: trackerURL, hasReceivedInit: false))
        policy.notePurgeOutcome(didRemoveAnything: false)
        #expect(!policy.onHTTPError(url: trackerURL, hasReceivedInit: false))
        #expect(policy.attemptsUsed == WebViewNoCacheRetryPolicy.maxAttempts)
    }

    @Test
    func noSecondGrantWhileThePurgeOutcomeIsPending() {
        let policy = policy()

        #expect(policy.onHTTPError(url: trackerURL, hasReceivedInit: false))
        #expect(!policy.onHTTPError(url: "https://cdn.test/other.js", hasReceivedInit: false))
        policy.notePurgeOutcome(didRemoveAnything: false)
        #expect(policy.onHTTPError(url: "https://cdn.test/other.js", hasReceivedInit: false))
    }

    @Test
    func doesNotRetryAfterTheRuntimeInitialized() {
        let policy = policy()

        #expect(!policy.onHTTPError(url: trackerURL, hasReceivedInit: true))
        #expect(!policy.hasRetried)
        #expect(policy.lastHTTPErrorDetail == "load failure (no HTTP status on WebKit) for \(trackerURL)")
    }

    @Test
    func doesNotRetryNonScriptResources() {
        let policy = policy()

        #expect(!policy.onHTTPError(url: "https://cdn.test/banner.png", hasReceivedInit: false))
        #expect(!policy.onHTTPError(
            url: "https://personalization-speedtest.g.mindbox.ru/client-stats?x=1",
            hasReceivedInit: false
        ))
        #expect(policy.lastHTTPErrorDetail == nil)
    }

    @Test
    func cacheFeatureOffBlocksTheRetryButKeepsTheTelemetryDetail() {
        let policy = policy(cacheEnabled: false)

        #expect(!policy.onHTTPError(url: trackerURL, hasReceivedInit: false))
        #expect(!policy.hasRetried)
        #expect(policy.lastHTTPErrorDetail == "load failure (no HTTP status on WebKit) for \(trackerURL)")
    }

    @Test
    func cacheGateIsConsultedOnlyWhenARetryWouldActuallyFire() {
        var consulted = 0
        let policy = WebViewNoCacheRetryPolicy {
            consulted += 1
            return true
        }

        _ = policy.onHTTPError(url: "https://cdn.test/banner.png", hasReceivedInit: false)
        #expect(consulted == 0)

        _ = policy.onHTTPError(url: trackerURL, hasReceivedInit: true)
        #expect(consulted == 0)

        _ = policy.onHTTPError(url: trackerURL, hasReceivedInit: false)
        #expect(consulted == 1)
    }
}
