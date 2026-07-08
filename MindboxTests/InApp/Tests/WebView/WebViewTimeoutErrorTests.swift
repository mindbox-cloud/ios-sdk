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
        guard case .webviewPresentationFailed = WebViewController.timeoutError(readyCheckGaveUp: true, inAppId: "x") else {
            Issue.record("expected webviewPresentationFailed when the ready check gave up")
            return
        }
        guard case .webviewLoadFailed = WebViewController.timeoutError(readyCheckGaveUp: false, inAppId: "x") else {
            Issue.record("expected webviewLoadFailed when the page never loaded")
            return
        }
    }
}
