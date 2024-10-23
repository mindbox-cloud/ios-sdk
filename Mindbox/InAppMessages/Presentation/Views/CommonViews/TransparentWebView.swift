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

    weak var delegate: ModalVCDelegate?

    override init(frame: CGRect) {
        super.init(frame: frame)
//        Self.clean()
        createWKWebView()
        setupWebView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        print("DEINIT TransparentView")
    }

    private func createWKWebView() {
        let contentController = WKUserContentController()
        contentController.add(self, name: "elementClicked")
        contentController.add(self, name: "classChanged")

        let jsObserver = """
                var observer = new MutationObserver(function(mutations) {
                    mutations.forEach(function(mutation) {
                        if (mutation.attributeName === 'class') {
                            var target = mutation.target;
                            console.log('Изменение класса: ', target.className);
                            window.webkit.messageHandlers.classChanged.postMessage(target.className);
                        }
                    });
                });

                var bodyElement = document.querySelector('body');  // Отслеживаем изменения классов у body
                observer.observe(bodyElement, { attributes: true });
                """

        // JavaScript для перехвата кликов на элемент с классом popmechanic-close
        let jsClick = """
                document.addEventListener('click', function(event) {
                    var target = event.target;
                    if (target.classList.contains('popmechanic-close')) {
                        window.webkit.messageHandlers.elementClicked.postMessage('close-button');
                    }
                });
                """

        let userScript = WKUserScript(source: jsClick, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        contentController.addUserScript(userScript)

        let userScriptForObserver = WKUserScript(source: jsObserver, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
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
        return """
        <!DOCTYPE html>
        <html lang="ru">
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                .popmechanic-js-paranja {
                    opacity: 0 !important;
                }
            </style>
            <script>
                mindbox = window.mindbox || function() { mindbox.queue.push(arguments); };
                mindbox.queue = mindbox.queue || [];
                mindbox('create', {
                endpointId: 'test-staging.personalization-test-site-staging.mindbox.ru'
                });
            </script>
            <script src="https://api-staging.mindbox.ru/scripts/v1/tracker.js" async></script>
        </head>
        </html>
        """
    }

    func loadHTMLPage() {
        let url = URL(string: "file://hello")
        webView.loadHTMLString(getHTML(), baseURL: url)
    }

    func cleanUp() {
        print(#function)

        webView.configuration.userContentController.removeScriptMessageHandler(forName: "elementClicked")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "classChanged")

        webView.navigationDelegate = nil
        webView.uiDelegate = nil
    }
}

// MARK: - WKScriptMessageHandler

extension TransparentWebView: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "elementClicked", let element = message.body as? String {
            if element == "close-button" {
                print("Клик по крестику закрытия!")
                delegate?.closeVC()
            }
        }

        if message.name == "classChanged", let className = message.body as? String {
            print("Класс элемента body изменился: \(className)")

            if className.contains("popmechanic-submitted") {
                print("Форма отправлена.")
            }

            if className == "popmechanic-submitted popmechanic-mobile popmechanic-success" {
                guard !isClosing else { return }
                isClosing = true
                print("Форма успешно отправлена! Закрываем WebView.")
                self.delegate?.closeVC()
            }
        }
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
