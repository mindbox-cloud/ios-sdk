//
//  TransparentWebView.swift
//  Mindbox
//
//  Created by vailence on 17.10.2024.
//

import UIKit
import WebKit
import MindboxLogger

final class TransparentWebView: UIView {
    
    weak var delegate: WebVCDelegate?
    weak var webViewAction: WebViewAction?
    
    private var webView: WKWebView!

    private var quizInitTimeoutWorkItem: DispatchWorkItem?

    private var params: [String: String]?

    init(frame: CGRect, params: [String: String]) {
        self.params = params
        super.init(frame: frame)
        createWKWebView()
        setupWebView()
        
        webView.backgroundColor = .clear
        webView.scrollView.delegate = self
        webView.scrollView.bounces = false
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        webView.scrollView.delegate = nil
        Logger.common(message: "[WebView] Deinit TransparentView", category: .webViewInAppMessages)
    }

    private func createWKWebView() {
        Logger.common(message: "[WebView] TransparentWebView: Creating WKWebView", category: .webViewInAppMessages)
        let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
        let contentController = WKUserContentController()
        contentController.add(self, name: "SdkBridge")

        var mindboxParams: [String: String] = [
            "sdkVersion": Mindbox.shared.sdkVersion,
            "endpointId": persistenceStorage.configuration?.endpoint ?? "",
            "deviceUuid": persistenceStorage.deviceUUID ?? "",
            "sdkVersionNumeric": "\(Constants.Versions.sdkVersionNumeric)"
        ]

        if let params = self.params {
            mindboxParams.merge(params) { _, new in new }
        }

        let lowercasedMindboxParams = Dictionary(uniqueKeysWithValues: mindboxParams.map { key, value in
            (key.lowercased(), value)
        })

        var sdkBridgeParamsObjectString = "{}"
        if let jsonData = try? JSONSerialization.data(withJSONObject: lowercasedMindboxParams),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            sdkBridgeParamsObjectString = jsonString
        }

        let jsObserver: String = """
             // Log UserAgent to console
             console.log('UserAgent:', navigator.userAgent);
             
             // Send UserAgent to native code
             window.webkit.messageHandlers.SdkBridge.postMessage({
                 'action': 'userAgent',
                 'data': navigator.userAgent
             });
         
             window.sdkBridgeParams = \(sdkBridgeParamsObjectString);
             
             window.SdkBridge = {
                 receiveParam: function(paramName) {
                     if (typeof paramName !== 'string') return;
                     return window.sdkBridgeParams[paramName.toLowerCase()];
                 }
             };
         """

        let userScriptForObserver = WKUserScript(source: jsObserver, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        
        contentController.addUserScript(userScriptForObserver)

        let webViewConfig = WKWebViewConfiguration()
        let prefs = WKPreferences()
        prefs.javaScriptEnabled = true
        #if DEBUG
        prefs.setValue(true, forKey: "developerExtrasEnabled")
        #endif

        webViewConfig.preferences = prefs
        webViewConfig.userContentController = contentController
        webViewConfig.applicationNameForUserAgent = createUserAgent()

        webView = WKWebView(frame: .zero, configuration: webViewConfig)
        webView.navigationDelegate = self
        Logger.common(message: "[WebView] TransparentWebView: WKWebView created with configuration", category: .webViewInAppMessages)
        
        #if DEBUG
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        #endif
    }

    private func setupWebView() {
        Logger.common(message: "[WebView] TransparentWebView: Setting up WebView", category: .webViewInAppMessages)
        webView.isOpaque = false
        self.addSubview(webView)
        setupWebViewConstraints()
    }

    func loadHTMLPage(baseUrl: String, contentUrl: String) {
        Logger.common(message: "[WebView] Starting to load HTML page", category: .webViewInAppMessages)
        Logger.common(message: "[WebView] Base URL: \(baseUrl)", category: .webViewInAppMessages)
        Logger.common(message: "[WebView] Content URL: \(contentUrl)", category: .webViewInAppMessages)
        
        setupTimeoutTimer()
        let url = URL(string: baseUrl)
        fetchHTMLContent(from: contentUrl) { htmlString in
            if let htmlString = htmlString {
                Logger.common(message: "[WebView] TransparentWebView: HTML content fetched successfully", category: .webViewInAppMessages)
                Logger.common(message: "[WebView] TransparentWebView: Loading HTML string into WebView", category: .webViewInAppMessages)
                DispatchQueue.main.async {
                    self.webView.loadHTMLString(htmlString, baseURL: url)
                }
            } else {
                Logger.common(message: "[WebView] TransparentWebView: Failed to fetch HTML content", category: .webViewInAppMessages)
                self.quizInitTimeoutWorkItem?.cancel()
                DispatchQueue.main.async {
                    self.delegate?.closeTimeoutWebViewVC()
                }
            }
        }
    }
    
    func fetchHTMLContent(from urlString: String, completion: @escaping (String?) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.urlCache = nil
        let session = URLSession(configuration: config)
        
        let task = session.dataTask(with: url) { data, response, error in
            if let error = error {
                Logger.common(message: "[WebView] TransparentWebView: Failed to fetch HTML content with error \(error.localizedDescription)", category: .webViewInAppMessages)
                completion(nil)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                Logger.common(message: "[WebView] TransparentWebView: Failed to fetch HTML content. Incorrect server response", category: .webViewInAppMessages)
                completion(nil)
                return
            }
            
            if let data = data, let htmlString = String(data: data, encoding: .utf8) {
                completion(htmlString)
            } else {
                completion(nil)
            }
        }
        task.resume()
    }

    func cleanUp() {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "SdkBridge")
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
    }
    
    private func createUserAgent() -> String {
        let utilitiesFetcher = DI.injectOrFail(UtilitiesFetcher.self)
        
        let sdkVersion = utilitiesFetcher.sdkVersion ?? "unknow"
        let appVersion = utilitiesFetcher.appVerson ?? "unknow"
        let appName = utilitiesFetcher.hostApplicationName ?? "unknow"
        let userAgent: String = "\(appName)/\(appVersion) mindbox.sdk/\(sdkVersion)"
        return userAgent
    }
    
    private func setupTimeoutTimer() {
        let secondsTimeout = 7
        Logger.common(message: "[WebView] TransparentWebView: setup timeout timer with \(secondsTimeout) seconds", category: .webViewInAppMessages)
        
        quizInitTimeoutWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            Logger.common(message: "[WebView] TransparentWebView: quiz init timeout reached, closing", category: .webViewInAppMessages)
            self?.delegate?.closeTimeoutWebViewVC()
        }
        quizInitTimeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(secondsTimeout), execute: workItem)
    }
}

// MARK: - WKScriptMessageHandler

extension TransparentWebView: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        let name = message.name
        
        if name == "SdkBridge", let messageBody = message.body as? [String: String] {
            let action = messageBody["action"] ?? "unknown"
            let data = messageBody["data"] ?? ""
            
            Logger.common(message: "[WebView] TransparentWebView: SdkBridge - received \(action) \(data)", category: .webViewInAppMessages)
            
            switch action {
            case "close":
                quizInitTimeoutWorkItem?.cancel()
                webViewAction?.onClose()
            case "init":
                quizInitTimeoutWorkItem?.cancel()
                webViewAction?.onInit()
            case "click":
                webViewAction?.onCompleted(data: data)
            case "hide":
                webViewAction?.onHide()
            case "log":
                webViewAction?.onLog(message: data)
            case "userAgent":
                print("TransparentWebView: UserAgent: \(data)")
            default:
                Logger.common(message: "[WebView] TransparentWebView: action: \(action) with \(data)", category: .webViewInAppMessages)
            }
        }
    }
}

// MARK: - WKNavigationDelegate

extension TransparentWebView: WKNavigationDelegate {
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

// MARK: - Constraints setup

extension TransparentWebView {
    private func setupWebViewConstraints() {
        webView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }
}

// MARK: - Clean cache

extension TransparentWebView {
    static func clean() {
        HTTPCookieStorage.shared.removeCookies(since: Date.distantPast)
        Logger.common(message: "[WebView] WebCacheCleaner: All cookies deleted", category: .webViewInAppMessages)

        WKWebsiteDataStore.default().fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
            records.forEach { record in
                WKWebsiteDataStore.default().removeData(ofTypes: record.dataTypes, for: [record], completionHandler: {})
                Logger.common(message: "[WebView] Record \(record) deleted", category: .webViewInAppMessages)
            }
        }
    }
}

extension TransparentWebView: UIScrollViewDelegate {
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
