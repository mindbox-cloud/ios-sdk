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

    /// The 7s init timeout stays the single closing authority, but monitoring must tell
    /// "page loaded, JS bridge never appeared" apart from "page never finished loading".
    @Test
    func timeoutDistinguishesBridgeMissingFromLoadFailure() {
        guard case .webviewPresentationFailed = WebViewController.timeoutError(readyCheckGaveUp: true) else {
            Issue.record("expected webviewPresentationFailed when the ready check gave up")
            return
        }
        guard case .webviewLoadFailed = WebViewController.timeoutError(readyCheckGaveUp: false) else {
            Issue.record("expected webviewLoadFailed when the page never loaded")
            return
        }
    }

    @Test
    func timeoutCarriesTheScriptHTTPErrorDetail() throws {
        let detail = "Last script HTTP error: HTTP 404 for https://cdn.test/tracker.js; no-cache retry attempted: true."

        guard case .webviewLoadFailed(let description) = WebViewController.timeoutError(
            readyCheckGaveUp: false, httpErrorDetail: detail
        ) else {
            Issue.record("expected webviewLoadFailed")
            return
        }
        #expect(description.hasSuffix(" \(detail)"))

        guard case .webviewLoadFailed(let plain) = WebViewController.timeoutError(
            readyCheckGaveUp: false, httpErrorDetail: nil
        ) else {
            Issue.record("expected webviewLoadFailed")
            return
        }
        #expect(!plain.contains("Last script HTTP error"))
    }

    /// Android sends the same texts, so one search finds the failure on both platforms.
    @Test
    func timeoutTextsMatchAndroid() {
        #expect(WebViewController.timeoutError(readyCheckGaveUp: false).failureDetails == "Page did not send init within 7s.")
        #expect(WebViewController.timeoutError(readyCheckGaveUp: true).failureDetails == "JS bridge not found on the loaded page within 7s.")
    }
}
