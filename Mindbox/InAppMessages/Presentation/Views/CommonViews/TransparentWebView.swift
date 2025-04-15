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
    
    private var webView: WKWebView!

    private var quizInitTimeoutWorkItem: DispatchWorkItem?

    override init(frame: CGRect) {
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
        contentController.add(self, name: "mindbox")

        let jsObserver: String = """
            function sdkVersionIos(){return '\(Mindbox.shared.sdkVersion)';}
            function endpointIdIos(){return '\("holodilnik-android")';}
            function deviceUuidIos(){return '\(persistenceStorage.deviceUUID ?? "error")';}
            
            // Log UserAgent to console
            console.log('UserAgent:', navigator.userAgent);
            
            // Send UserAgent to native code
            window.webkit.messageHandlers.mindbox.postMessage({
                'action': 'userAgent',
                'data': navigator.userAgent
            });
        """
        
        let scrollPreventionScript = """
            // Block all scroll events
            document.addEventListener('touchmove', function(e) {
                e.preventDefault();
            }, { passive: false });
        """

        let userScriptForObserver = WKUserScript(source: jsObserver, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        let userScriptForScrollPrevention = WKUserScript(source: scrollPreventionScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        
        contentController.addUserScript(userScriptForObserver)
        contentController.addUserScript(userScriptForScrollPrevention)

        let webViewConfig = WKWebViewConfiguration()
        webViewConfig.userContentController = contentController

        webView = WKWebView(frame: .zero, configuration: webViewConfig)
        webView.navigationDelegate = self
        Logger.common(message: "[WebView] TransparentWebView: WKWebView created with configuration", category: .webViewInAppMessages)

        webView.customUserAgent = createUserAgent()
        
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
    }

    private func setupWebView() {
        Logger.common(message: "[WebView] TransparentWebView: Setting up WebView", category: .webViewInAppMessages)
        webView.isOpaque = false
        self.addSubview(webView)
        setupWebViewConstraints()
    }

    func getHTML() -> String {
        return ""
    }

    func loadHTMLPage(baseUrl: String, contentUrl: String) {
        Logger.common(message: "[WebView] Starting to load HTML page", category: .webViewInAppMessages)
        Logger.common(message: "[WebView] Base URL: \(baseUrl)", category: .webViewInAppMessages)
        Logger.common(message: "[WebView] Content URL: \(contentUrl)", category: .webViewInAppMessages)
        
        // Сброс предыдущего таймера
        quizInitTimeoutWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            Logger.common(message: "[WebView] TransparentWebView: quiz init timeout reached, closing", category: .webViewInAppMessages)
            self?.delegate?.closeTapWebViewVC()
        }
        quizInitTimeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(5), execute: workItem)
        print(Date())
        
        let url = URL(string: baseUrl)
        fetchHTMLContent(from: contentUrl) { htmlString in
            if let htmlString = htmlString {
                Logger.common(message: "[WebView] TransparentWebView: HTML content fetched successfully", category: .webViewInAppMessages)
                DispatchQueue.main.async {
                    Logger.common(message: "[WebView] TransparentWebView: Loading HTML string into WebView", category: .webViewInAppMessages)
                    self.webView.loadHTMLString(htmlString, baseURL: url)
                }
            } else {
                Logger.common(message: "[WebView] TransparentWebView: Failed to fetch HTML content", category: .webViewInAppMessages)
                DispatchQueue.main.async {
                    print(Date())
                    self.quizInitTimeoutWorkItem?.cancel()
                    self.delegate?.closeTapWebViewVC()
                }
            }
        }
    }
    
    func fetchHTMLContent(from urlString: String, completion: @escaping (String?) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
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
                DispatchQueue.main.async {
                    completion(nil)
                }
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
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "mindbox")

        webView.navigationDelegate = nil
        webView.uiDelegate = nil
    }
    
    private func createUserAgent() -> String {
        let utilitiesFetcher = DI.injectOrFail(UtilitiesFetcher.self)
        
        let sdkVersion = utilitiesFetcher.sdkVersion ?? "unknow"
        let appVersion = utilitiesFetcher.appVerson ?? "unknow"
        let appName = utilitiesFetcher.hostApplicationName ?? "unknow"
        let userAgent: String = "mindbox.sdk/\(sdkVersion) (iPhone \(DeviceModelHelper.os) \(DeviceModelHelper.iOSVersion); \(DeviceModelHelper.model)) \(appName)/\(appVersion)"
        return userAgent
    }
}

// MARK: - WKScriptMessageHandler

extension TransparentWebView: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        print(message.body, message.name)
        let name = message.name
        
        if name == "mindbox", let messageBody = message.body as? [String: String] {
            let action = messageBody["action"] ?? "unknown"
            let data = messageBody["data"] ?? ""
            
            switch action {
            case "close":
                delegate?.closeTapWebViewVC()
            case "collapse":
                delegate?.closeTapWebViewVC()
            case "init":
                Logger.common(message: "[WebView] TransparentWebView: received init action", category: .webViewInAppMessages)
                if data.contains("quiz") {
                    // Останавливаем таймер, если quiz init пришёл вовремя
                    quizInitTimeoutWorkItem?.cancel()
                    print(Date())
                    DispatchQueue.main.async {
                        if let window = UIApplication.shared.windows.first(where: {
                            $0.rootViewController is WebViewController
                        }) {
                            window.isHidden = false
                            window.makeKeyAndVisible()
                            Logger.common(message: "[WebView] TransparentWebView: Window is now visible", category: .webViewInAppMessages)
                        }
                    }
                }
            case "userAgent":
                print("TransparentWebView: UserAgent: \(data)")
            default:
                Logger.common(message: "[WebView] TransparentWebView: action: \(action) with \(data)", category: .webViewInAppMessages)
                print("action: \(action) with \(data)")
            }
        }
    }
}

// {"mode":"quiz","screen":"minimal","slug":"televisions","action":"show"}
class RequestBody: Decodable {
    let mode: String
    let screen: String
    let slug: String
    let action: String
    
    init(mode: String, screen: String, slug: String, action: String) {
        self.mode = mode
        self.screen = screen
        self.slug = slug
        self.action = action
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
