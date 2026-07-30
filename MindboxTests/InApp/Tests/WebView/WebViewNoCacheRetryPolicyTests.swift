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
        // The purge provably removed the poisoned entry — a later error means the poison
        // is upstream, another reload would just replay the failure.
        #expect(!policy.onHTTPError(url: trackerURL, hasReceivedInit: false))
        // The later error still refreshes the telemetry detail.
        #expect(!policy.onHTTPError(url: "https://cdn.test/other.js", hasReceivedInit: false))
        #expect(policy.lastHTTPErrorDetail == "load failure (no HTTP status on WebKit) for https://cdn.test/other.js")
    }

    /// Write-behind race (spec D2a): on the very first poisoning the entry may not be
    /// visible to the purge yet. An empty purge keeps the retry armed for one more attempt.
    @Test
    func emptyPurgeAllowsExactlyOneMoreAttempt() {
        let policy = policy()

        #expect(policy.onHTTPError(url: trackerURL, hasReceivedInit: false))
        policy.notePurgeOutcome(didRemoveAnything: false)
        #expect(policy.onHTTPError(url: trackerURL, hasReceivedInit: false))
        policy.notePurgeOutcome(didRemoveAnything: false)
        // Hard cap: two attempts per show session whatever the purge outcomes were —
        // repeated empty purges mean the poison is not in the client cache (offline/CDN).
        #expect(!policy.onHTTPError(url: trackerURL, hasReceivedInit: false))
        #expect(policy.attemptsUsed == WebViewNoCacheRetryPolicy.maxAttempts)
    }

    /// A second error report (another failing script, or a duplicate message posted by
    /// page JS) must not double-fire the retry while the first purge has not reported back.
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
        // A live in-app must not be reloaded, but the error is still worth remembering.
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
