//
//  TransparentWebView.swift
//  Mindbox
//
//  Created by vailence on 17.10.2024.
//

import UIKit
import WebKit

final class TransparentWebView: UIView {
    private var webView: WKWebView!

    private var isClosing: Bool = false

    weak var delegate: WebVCDelegate?

    override init(frame: CGRect) {
        super.init(frame: frame)
//        Self.clean()
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
        print("DEINIT TransparentView")
    }

    private func createWKWebView() {
        let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
        let contentController = WKUserContentController()
        contentController.add(self, name: "mindbox")

        //let userScript = WKUserScript(source: jsClick, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        //contentController.addUserScript(userScript)
        
        let jsObserver: String = """
            function sdkVersionIos(){return '\(Mindbox.shared.sdkVersion)';}
            function endpointIdIos(){return '\("Test-staging.mobile-sdk-test-staging.mindbox.ru")';}
            function deviceUuidIos(){return '\(persistenceStorage.deviceUUID!)';}
        """

        let userScriptForObserver = WKUserScript(source: jsObserver, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        contentController.addUserScript(userScriptForObserver)

        let webViewConfig = WKWebViewConfiguration()
        webViewConfig.userContentController = contentController

        webView = WKWebView(frame: .zero, configuration: webViewConfig)
        webView.navigationDelegate = self // WKNavigationDelegate

        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
    }

    private func setupWebView() {
        webView.isOpaque = false
        self.addSubview(webView)
        setupWebViewConstraints()
    }

    func getHTML() -> String {
        return ""
    }

    func loadHTMLPage(baseUrl: String, contentUrl: String) {
        let url = URL(string: baseUrl)
        fetchHTMLContent(from: contentUrl) { htmlString in
            if let htmlString = htmlString {
                print("Содержимое страницы \(baseUrl) загружено")
                DispatchQueue.main.async {
                    self.webView.loadHTMLString(htmlString, baseURL: url)
                }
            } else {
                print("Не удалось загрузить HTML")
                DispatchQueue.main.async {
                    self.delegate?.closeVC()
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
                print("Ошибка загрузки данных: \(error)")
                completion(nil)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                print("Некорректный ответ сервера")
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
        print(#function)

        webView.configuration.userContentController.removeScriptMessageHandler(forName: "mindbox")

        webView.navigationDelegate = nil
        webView.uiDelegate = nil
    }
}

// MARK: - WKScriptMessageHandler

extension TransparentWebView: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        
        let name = message.name
        
        if name == "mindbox", let messageBody = message.body as? [String: String] {
        
            let action = messageBody["action"] ?? "unknown"
            let data = messageBody["data"] ?? ""
            
            switch action {
            case "close":
                delegate?.closeVC()
            case "collapse":
                delegate?.closeVC()
            default:
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
        print("Начало загрузки URL: \(webView.url?.absoluteString ?? "unknown")")
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("Загрузка завершена: \(webView.url?.absoluteString ?? "unknown")")
    }

    func webView(
        _ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
    ) {
        if let url = navigationAction.request.url {
            print("Переход по URL: \(url.absoluteString)")
        }
        decisionHandler(.allow)
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: any Error
    ) {
        print("Ошибка загрузки: \(error.localizedDescription)")
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
        print("[WebCacheCleaner] All cookies deleted")

        WKWebsiteDataStore.default().fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
            records.forEach { record in
                WKWebsiteDataStore.default().removeData(ofTypes: record.dataTypes, for: [record], completionHandler: {})
                print("[WebCacheCleaner] Record \(record) deleted")
            }
        }
    }
}

extension TransparentWebView: UIScrollViewDelegate  {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return nil
    }
}
