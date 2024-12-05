//
//  WebView.swift
//  Example
//
//  Created by Sergei Semko on 11/27/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import SwiftUI
import WebKit
import Mindbox

struct WebView: UIViewRepresentable {

    static var currentWebView: WKWebView?

    let url: URL?
    var viewModel: ViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    func makeUIView(context: Context) -> WKWebView {
        let wkWebView = WKWebView()
        wkWebView.navigationDelegate = context.coordinator

#if DEBUG
        // Use this to enable debug
        wkWebView.isInspectable = true
#endif

        guard let url else { return wkWebView }

        let request = URLRequest(url: url)
        wkWebView.load(request)

        WebView.currentWebView = wkWebView
        return wkWebView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) { }

    final class Coordinator: NSObject {
        var viewModel: ViewModel

        init(viewModel: ViewModel) {
            self.viewModel = viewModel
        }
    }
}

// MARK: - WKNavigationDelegate

extension WebView.Coordinator: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        viewModel.syncMindboxDeviceUUIDs(with: webView)

        let message = "[WebView]: \(#function): Content started arriving for: \(webView.url?.absoluteString ?? "Unknown URL")"
        Mindbox.logger.log(level: .debug, message: message)
    }
}
