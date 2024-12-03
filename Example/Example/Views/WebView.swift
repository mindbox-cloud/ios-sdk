//
//  WebView.swift
//  Example
//
//  Created by Sergei Semko on 11/27/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import SwiftUI
import WebKit
import MindboxLogger

struct WebView: UIViewRepresentable {
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

        viewModel.setWebView(wkWebView)

        return wkWebView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) { }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var viewModel: ViewModel

        init(viewModel: ViewModel) {
            self.viewModel = viewModel
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            viewModel.syncMindboxDeviceUUIDs()

            let message = "[WebView]: \(#function): Content started arriving for: \(webView.url?.absoluteString ?? "Unknown URL")"
            Logger.common(message: message)
        }
    }
}
