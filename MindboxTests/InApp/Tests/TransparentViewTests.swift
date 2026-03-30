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
