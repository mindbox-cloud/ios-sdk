//
//  TransparentViewTests.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 05.03.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
@testable import Mindbox

@Suite("TransparentView timeout configuration tests")
struct TransparentViewTests {

    @Test("WebView timeout constant equals 7 seconds", .tags(.webView))
    func webViewTimeoutIsSevenSeconds() {
        #expect(Constants.WebView.timeoutSeconds == 7)
    }
}

@Suite("WebView ready check retry", .tags(.webView))
struct WebViewReadyCheckerTests {

    /// Drives the checker synchronously: `evaluate` answers from a scripted sequence and
    /// scheduled retries run immediately (or are held for the cancel test).
    private final class Harness {
        var answers: [Result<Any?, Error>]
        private(set) var evaluateCount = 0
        private(set) var scheduledDelays: [TimeInterval] = []
        private(set) var pendingWork: [() -> Void] = []
        let runScheduledImmediately: Bool

        init(answers: [Result<Any?, Error>], runScheduledImmediately: Bool = true) {
            self.answers = answers
            self.runScheduledImmediately = runScheduledImmediately
        }

        func makeChecker() -> WebViewReadyChecker {
            WebViewReadyChecker(
                evaluate: { [self] _, completion in
                    evaluateCount += 1
                    completion(answers.isEmpty ? .success(false) : answers.removeFirst())
                },
                schedule: { [self] delay, work in
                    scheduledDelays.append(delay)
                    if runScheduledImmediately {
                        work()
                    } else {
                        pendingWork.append(work)
                    }
                }
            )
        }
    }

    @Test("An immediately ready page passes on the first attempt")
    func readyFirstAttempt() {
        let harness = Harness(answers: [.success(true)])
        var readyCalls = 0
        harness.makeChecker().run(onReady: { readyCalls += 1 }, onGiveUp: { _ in Issue.record("must not give up") })

        #expect(readyCalls == 1)
        #expect(harness.evaluateCount == 1)
        #expect(harness.scheduledDelays.isEmpty)
    }

    @Test("A module evaluating after didFinish passes on a retry instead of closing the show")
    func readyAfterRetries() {
        let harness = Harness(answers: [.success(false), .success(nil), .success(true)])
        var readyCalls = 0
        harness.makeChecker().run(onReady: { readyCalls += 1 }, onGiveUp: { _ in Issue.record("must not give up") })

        #expect(readyCalls == 1)
        #expect(harness.evaluateCount == 3)
        #expect(harness.scheduledDelays == [WebViewReadyChecker.retryDelay, WebViewReadyChecker.retryDelay])
    }

    @Test("Evaluation errors are retried like a plain false, not closed on immediately")
    func evaluationErrorRetries() {
        let error = NSError(domain: "test", code: 1)
        let harness = Harness(answers: [.failure(error), .success(true)])
        var readyCalls = 0
        harness.makeChecker().run(onReady: { readyCalls += 1 }, onGiveUp: { _ in Issue.record("must not give up") })

        #expect(readyCalls == 1)
        #expect(harness.evaluateCount == 2)
    }

    @Test("A page that never boots gives up only after the full retry budget")
    func givesUpAfterBudget() {
        let harness = Harness(answers: [])
        var giveUpReasons: [String] = []
        harness.makeChecker().run(onReady: { Issue.record("must not become ready") },
                                  onGiveUp: { giveUpReasons.append($0) })

        #expect(giveUpReasons.count == 1)
        #expect(harness.evaluateCount == WebViewReadyChecker.maxAttempts)
    }

    @Test("Cancel abandons the poll without ever resolving")
    func cancelAbandonsSilently() {
        let harness = Harness(answers: [], runScheduledImmediately: false)
        let checker = harness.makeChecker()
        checker.run(onReady: { Issue.record("must not become ready") },
                    onGiveUp: { _ in Issue.record("must not give up") })
        #expect(harness.evaluateCount == 1)

        checker.cancel()
        harness.pendingWork.forEach { $0() }

        // The cancelled checker neither evaluates again nor resolves.
        #expect(harness.evaluateCount == 1)
    }
}
