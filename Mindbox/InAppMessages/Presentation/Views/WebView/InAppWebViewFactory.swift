//
//  InAppWebViewFactory.swift
//  Mindbox
//
//  Created by Sergei Semko on 07.07.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import WebKit

enum InAppWebViewFactory {

    static func make(userAgent: String = SDKUserAgent.build()) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = InAppWebViewDataStore.shared()
        config.applicationNameForUserAgent = userAgent
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.userContentController.addUserScript(
            WKUserScript(
                source: Constants.WebViewHTTPErrorJS.detectionScript,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            )
        )
        let webView = WKWebView(frame: .zero, configuration: config)
        #if DEBUG
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        #endif
        return webView
    }
}
