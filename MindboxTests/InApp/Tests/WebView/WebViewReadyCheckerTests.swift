//
//  WebViewReadyCheckerTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 06.07.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
import JavaScriptCore
@testable import Mindbox

@Suite("WebView ready check retry", .tags(.webView))
struct WebViewReadyCheckerTests {

    private let ready: Any? = Constants.WebViewBridgeJS.bridgeReady
    private let noHandlers: Any? = Constants.WebViewBridgeJS.bridgeNoPageHandlers
    private let noNativeBridge: Any? = Constants.WebViewBridgeJS.bridgeNoNativeHandler

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
        let harness = Harness(answers: [.success(ready)])
        var readyCount = 0

        harness.makeChecker().run(onReady: { readyCount += 1 }, onGiveUp: { _ in Issue.record("unexpected give-up") })

        #expect(readyCount == 1)
        #expect(harness.evaluateCount == 1)
        #expect(harness.pendingWork.isEmpty)
    }

    @Test("A module evaluating after didFinish passes on a retry instead of failing the show")
    func readyAfterRetries() {
        let harness = Harness(answers: [.success(noHandlers), .success(noHandlers), .success(ready)])
        var readyCount = 0

        let checker = harness.makeChecker()
        checker.run(onReady: { readyCount += 1 }, onGiveUp: { _ in Issue.record("unexpected give-up") })
        harness.runPending()
        harness.runPending()

        withExtendedLifetime(checker) {}
        #expect(readyCount == 1)
        #expect(harness.evaluateCount == 3)
    }

    @Test("Evaluation errors are retried like a not-ready status")
    func evaluationErrorRetries() {
        let error = NSError(domain: "test", code: 1)
        let harness = Harness(answers: [.failure(error), .success(ready)])
        var readyCount = 0

        let checker = harness.makeChecker()
        checker.run(onReady: { readyCount += 1 }, onGiveUp: { _ in Issue.record("unexpected give-up") })
        harness.runPending()

        withExtendedLifetime(checker) {}
        #expect(readyCount == 1)
    }

    @Test("A page that never boots gives up only after the full retry budget")
    func givesUpAfterBudget() {
        let harness = Harness(answers: Array(repeating: .success(noHandlers), count: WebViewReadyChecker.maxAttempts))
        var giveUpFailure: String?

        let checker = harness.makeChecker()
        checker.run(onReady: { Issue.record("unexpected ready") }, onGiveUp: { giveUpFailure = $0 })
        while !harness.pendingWork.isEmpty {
            harness.runPending()
        }

        withExtendedLifetime(checker) {}
        #expect(harness.evaluateCount == WebViewReadyChecker.maxAttempts)
        #expect(giveUpFailure == "no-handlers: window.bridgeMessagesHandlers.emit is missing")
    }

    @Test("A missing native handler gives up with a failure naming the native bridge")
    func missingNativeBridgeNamedInFailure() {
        let harness = Harness(answers: Array(repeating: .success(noNativeBridge), count: WebViewReadyChecker.maxAttempts))
        var giveUpFailure: String?

        let checker = harness.makeChecker()
        checker.run(onReady: { Issue.record("unexpected ready") }, onGiveUp: { giveUpFailure = $0 })
        while !harness.pendingWork.isEmpty {
            harness.runPending()
        }

        withExtendedLifetime(checker) {}
        #expect(giveUpFailure == "no-native-bridge: window.webkit.messageHandlers.SdkBridge.postMessage is missing")
    }

    @Test("A bare boolean is not mistaken for the ready status")
    func booleanIsNotReady() {
        let harness = Harness(answers: Array(repeating: .success(true), count: WebViewReadyChecker.maxAttempts))
        var giveUpFailure: String?

        let checker = harness.makeChecker()
        checker.run(onReady: { Issue.record("unexpected ready") }, onGiveUp: { giveUpFailure = $0 })
        while !harness.pendingWork.isEmpty {
            harness.runPending()
        }

        withExtendedLifetime(checker) {}
        #expect(giveUpFailure?.hasPrefix("unexpected ready check result") == true)
    }

    @Test("Cancel abandons the poll without ever resolving")
    func cancelAbandonsSilently() {
        let harness = Harness(answers: [.success(noHandlers), .success(ready)])
        let checker = harness.makeChecker()

        checker.run(onReady: { Issue.record("resolved after cancel") }, onGiveUp: { _ in Issue.record("resolved after cancel") })
        checker.cancel()
        harness.runPending()

        #expect(harness.evaluateCount == 1)
    }
}

@Suite("WebView ready check script", .tags(.webView))
struct WebViewReadyCheckScriptTests {

    struct Page: CustomTestStringConvertible, Sendable {
        let name: String
        let nativeBridge: Bool
        let pageHandlers: Bool
        let expected: String

        var testDescription: String { name }
    }

    @Test("The script reports which half of the bridge is missing", arguments: [
        Page(name: "nothing", nativeBridge: false, pageHandlers: false, expected: Constants.WebViewBridgeJS.bridgeNoNativeHandler),
        Page(name: "native bridge only", nativeBridge: true, pageHandlers: false, expected: Constants.WebViewBridgeJS.bridgeNoPageHandlers),
        Page(name: "page handlers only", nativeBridge: false, pageHandlers: true, expected: Constants.WebViewBridgeJS.bridgeNoNativeHandler),
        Page(name: "both", nativeBridge: true, pageHandlers: true, expected: Constants.WebViewBridgeJS.bridgeReady)
    ])
    func reportsStatus(page: Page) throws {
        let context = try #require(JSContext())
        context.evaluateScript("var window = {};")
        if page.nativeBridge {
            context.evaluateScript(
                "window.webkit = { messageHandlers: { \(Constants.WebViewBridgeJS.handlerName): { postMessage: function () {} } } };"
            )
        }
        if page.pageHandlers {
            context.evaluateScript("window.bridgeMessagesHandlers = { emit: function () {} };")
        }

        let result = context.evaluateScript(Constants.WebViewBridgeJS.bridgeFunctionReadyCheck)

        #expect(context.exception == nil)
        #expect(result?.toString() == page.expected)
    }

    @Test("A handler without a callable postMessage is not a native bridge")
    func handlerWithoutPostMessage() throws {
        let context = try #require(JSContext())
        context.evaluateScript("""
            var window = {
                webkit: { messageHandlers: { \(Constants.WebViewBridgeJS.handlerName): { postMessage: undefined } } },
                bridgeMessagesHandlers: { emit: function () {} }
            };
            """)

        let result = context.evaluateScript(Constants.WebViewBridgeJS.bridgeFunctionReadyCheck)

        #expect(result?.toString() == Constants.WebViewBridgeJS.bridgeNoNativeHandler)
    }
}
