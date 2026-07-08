//
//  WebViewReadyCheckerTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 06.07.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
@testable import Mindbox

@Suite("WebView ready check retry", .tags(.webView))
struct WebViewReadyCheckerTests {

    /// Scripted evaluate answers + manual control over the retry schedule.
    private final class Harness {
        var answers: [Result<Any?, Error>]
        private(set) var evaluateCount = 0
        private(set) var pendingWork: [() -> Void] = []

        init(answers: [Result<Any?, Error>]) {
            self.answers = answers
        }

        func makeChecker() -> WebViewReadyChecker {
            WebViewReadyChecker(
                evaluate: { [self] _, completion in
                    evaluateCount += 1
                    completion(answers.removeFirst())
                },
                schedule: { [self] _, work in pendingWork.append(work) }
            )
        }

        func runPending() {
            let work = pendingWork
            pendingWork = []
            work.forEach { $0() }
        }
    }

    @Test("An immediately ready page passes on the first attempt")
    func readyFirstAttempt() {
        let harness = Harness(answers: [.success(true)])
        var readyCount = 0

        harness.makeChecker().run(onReady: { readyCount += 1 }, onGiveUp: { _ in Issue.record("unexpected give-up") })

        #expect(readyCount == 1)
        #expect(harness.evaluateCount == 1)
        #expect(harness.pendingWork.isEmpty)
    }

    @Test("A module evaluating after didFinish passes on a retry instead of failing the show")
    func readyAfterRetries() {
        let harness = Harness(answers: [.success(false), .success(false), .success(true)])
        var readyCount = 0

        let checker = harness.makeChecker()
        checker.run(onReady: { readyCount += 1 }, onGiveUp: { _ in Issue.record("unexpected give-up") })
        harness.runPending()
        harness.runPending()

        withExtendedLifetime(checker) {}
        #expect(readyCount == 1)
        #expect(harness.evaluateCount == 3)
    }

    @Test("Evaluation errors are retried like a plain false")
    func evaluationErrorRetries() {
        let error = NSError(domain: "test", code: 1)
        let harness = Harness(answers: [.failure(error), .success(true)])
        var readyCount = 0

        let checker = harness.makeChecker()
        checker.run(onReady: { readyCount += 1 }, onGiveUp: { _ in Issue.record("unexpected give-up") })
        harness.runPending()

        withExtendedLifetime(checker) {}
        #expect(readyCount == 1)
    }

    @Test("A page that never boots gives up only after the full retry budget")
    func givesUpAfterBudget() {
        let harness = Harness(answers: Array(repeating: .success(false), count: WebViewReadyChecker.maxAttempts))
        var giveUpFailure: String?

        let checker = harness.makeChecker()
        checker.run(onReady: { Issue.record("unexpected ready") }, onGiveUp: { giveUpFailure = $0 })
        while !harness.pendingWork.isEmpty {
            harness.runPending()
        }

        withExtendedLifetime(checker) {}
        #expect(harness.evaluateCount == WebViewReadyChecker.maxAttempts)
        #expect(giveUpFailure == "window.bridgeMessagesHandlers.emit is missing")
    }

    @Test("Cancel abandons the poll without ever resolving")
    func cancelAbandonsSilently() {
        let harness = Harness(answers: [.success(false), .success(true)])
        let checker = harness.makeChecker()

        checker.run(onReady: { Issue.record("resolved after cancel") }, onGiveUp: { _ in Issue.record("resolved after cancel") })
        checker.cancel()
        harness.runPending()

        #expect(harness.evaluateCount == 1)
    }
}
