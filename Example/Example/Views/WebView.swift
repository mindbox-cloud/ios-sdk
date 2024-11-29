//
//  WebView.swift
//  Example
//
//  Created by Sergei Semko on 11/27/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import SwiftUI
@preconcurrency import WebKit

struct WebView: UIViewRepresentable {
    let url: URL

    var viewModel: ViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    func makeUIView(context: Context) -> WKWebView {
        let wkWebView = WKWebView()
        wkWebView.navigationDelegate = context.coordinator

#if DEBUG
        wkWebView.isInspectable = true
#endif

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

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            print(#function)
            viewModel.isLoading = true
            viewModel.errorMessage = nil
            print("Page started loading: \(webView.url?.absoluteString ?? "Unknown URL")")
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            viewModel.clearAllWebData(webView)
            viewModel.setupWebViewForSync()
            print(#function)
            print("Content started arriving for: \(webView.url?.absoluteString ?? "Unknown URL")")
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print(#function)
            print("Page finished loading: \(webView.url?.absoluteString ?? "Unknown URL")")
            viewModel.isLoading = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
            print(#function)
            viewModel.isLoading = false
            viewModel.errorMessage = error.localizedDescription
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print(#function)
            print("loading error: \(error)")
            viewModel.isLoading = false
            viewModel.errorMessage = error.localizedDescription
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url?.absoluteString, url.contains("tracker.js") {
                print("Intercepted tracker.js: \(url)")
            }
            decisionHandler(.allow)
        }
    }
}
