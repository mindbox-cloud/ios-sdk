//
//  WebViewTimeoutErrorTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 06.07.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
@testable import Mindbox

@Suite("WebView timeout error category", .tags(.webView))
struct WebViewTimeoutErrorTests {

    @Test
    func timeoutDistinguishesBridgeMissingFromLoadFailure() {
        guard case .webviewPresentationFailed = WebViewController.timeoutError(readyCheckFailure: "no-handlers: window.bridgeMessagesHandlers.emit is missing") else {
            Issue.record("expected webviewPresentationFailed when the ready check gave up")
            return
        }
        guard case .webviewLoadFailed = WebViewController.timeoutError(readyCheckFailure: nil) else {
            Issue.record("expected webviewLoadFailed when the page never loaded")
            return
        }
    }

    @Test
    func bridgeMissingTimeoutNamesTheMissingHalf() {
        let failure = "no-native-bridge: window.webkit.messageHandlers.SdkBridge.postMessage is missing"

        guard case .webviewPresentationFailed(let description) = WebViewController.timeoutError(
            readyCheckFailure: failure
        ) else {
            Issue.record("expected webviewPresentationFailed")
            return
        }
        #expect(description.contains(failure))
    }

    @Test
    func timeoutCarriesTheScriptHTTPErrorDetail() throws {
        let detail = "Last script HTTP error: HTTP 404 for https://cdn.test/tracker.js; no-cache retry attempted: true."

        guard case .webviewLoadFailed(let description) = WebViewController.timeoutError(
            readyCheckFailure: nil, httpErrorDetail: detail
        ) else {
            Issue.record("expected webviewLoadFailed")
            return
        }
        #expect(description.hasSuffix(" \(detail)"))

        guard case .webviewLoadFailed(let plain) = WebViewController.timeoutError(
            readyCheckFailure: nil, httpErrorDetail: nil
        ) else {
            Issue.record("expected webviewLoadFailed")
            return
        }
        #expect(!plain.contains("Last script HTTP error"))
    }

    @Test
    func timeoutTextsMatchAndroid() {
        #expect(WebViewController.timeoutError(readyCheckFailure: nil).failureDetails == "Page did not send init within 7s.")
        #expect(WebViewController.timeoutError(readyCheckFailure: "no-handlers").failureDetails == "JS bridge not found on the loaded page within 7s: no-handlers.")
    }
}
