//
//  TransparentView.swift
//  Mindbox
//
//  Created by vailence on 17.10.2024.
//

import UIKit
import WebKit
import MindboxLogger

final class TransparentView: UIView {

    weak var delegate: WebVCDelegate?
    weak var webViewAction: WebViewAction?

    private var facade: MindboxInternalWebViewFacadeProtocol?
    private var quizInitTimeoutWorkItem: DispatchWorkItem?
    private var params: [String: String]?
    private let userAgent: String

    init(frame: CGRect, params: [String: String], userAgent: String) {
        self.params = params
        self.userAgent = userAgent
        super.init(frame: frame)
        commonInit()
    }

    override init(frame: CGRect) {
        self.params = nil
        self.userAgent = ""
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        self.params = nil
        self.userAgent = ""
        super.init(coder: coder)
        commonInit()
    }

    deinit {
        Logger.common(message: "[WebView] Deinit TransparentView", category: .webViewInAppMessages)
    }

    private func commonInit() {
        createFacade()

        guard let view = facade?.makeView() else {
            return
        }
        addSubview(view)
        setupViewConstraints(view)

        facade?.applyViewSettings(scrollViewDelegate: self)
    }

    private func createFacade() {
        facade = MindboxInternalWebViewFacade(params: params, userAgent: userAgent)
        facade?.setBridgeDelegate(self)
    }

    func loadHTMLPage(baseUrl: String, contentUrl: String) {
        setupTimeoutTimer()

        facade?.loadHTML(baseUrl: baseUrl, contentUrl: contentUrl) { [weak self] in
            self?.quizInitTimeoutWorkItem?.cancel()
            self?.delegate?.closeTimeoutWebViewVC()
        }
    }

    func cleanUp() {
        facade?.cleanWebView()
    }

    private func setupTimeoutTimer() {
        let secondsTimeout = 7

        quizInitTimeoutWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.delegate?.closeTimeoutWebViewVC()
        }
        quizInitTimeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(secondsTimeout), execute: workItem)
    }
}

// MARK: - Constraints setup
extension TransparentView {
    private func setupViewConstraints(_ view: UIView) {
        view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: topAnchor),
            view.bottomAnchor.constraint(equalTo: bottomAnchor),
            view.leadingAnchor.constraint(equalTo: leadingAnchor),
            view.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }
}

extension TransparentView: WebBridgeScriptDelegate {
    func webBridge(_ bridge: WebBridge, didReceiveFromJS message: WKScriptMessage) {
//        let action = message.action
//        let data = message.payloadAny as? String ?? ""
//
//        Logger.common(
//            message: "[WebView] Bridge: received \(action) \(data)",
//            category: .webViewInAppMessages
//        )
//
//        switch action {
//        case "close":
//            quizInitTimeoutWorkItem?.cancel()
//            webViewAction?.onClose()
//
//        case "init":
//            quizInitTimeoutWorkItem?.cancel()
//            webViewAction?.onInit()
//
//        case "click":
//            webViewAction?.onCompleted(data: data)
//
//        case "hide":
//            webViewAction?.onHide()
//
//        case "log":
//            webViewAction?.onLog(message: data)
//
//        case "userAgent":
//            Logger.common(
//                message: "[WebView] UserAgent: \(data)",
//                category: .webViewInAppMessages
//            )
//
//        default:
//            Logger.common(
//                message: "[WebView] Unknown action: \(action) with \(data)",
//                category: .webViewInAppMessages
//            )
//        }
    }
}

// MARK: - WKNavigationDelegate

extension TransparentView: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        Logger.common(message: "[WebView] WKNavigationDelegate: start loading URL \(webView.url?.absoluteString ?? "unknown")", category: .webViewInAppMessages)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Logger.common(message: "[WebView] WKNavigationDelegate: Upload completed \(webView.url?.absoluteString ?? "unknown")", category: .webViewInAppMessages)
    }

    func webView(
        _ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
    ) {
        if let url = navigationAction.request.url {
            Logger.common(message: "[WebView] WKNavigationDelegate: Navigating by URL \(url.absoluteString)", category: .webViewInAppMessages)
        }
        decisionHandler(.allow)
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: any Error
    ) {
        Logger.common(message: "[WebView] WKNavigationDelegate: Loading error \(error.localizedDescription)", category: .webViewInAppMessages)
    }
}

extension TransparentView: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return nil
    }
}

protocol WebViewAction: AnyObject {
    func onInit()
    func onCompleted(data: String)
    func onClose()
    func onHide()
    func onLog(message: String)
}
