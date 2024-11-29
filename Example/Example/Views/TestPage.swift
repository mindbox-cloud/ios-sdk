//
//  TestPage.swift
//  Example
//
//  Created by Sergei Semko on 11/28/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//


//  webViewTestApp.swift
//  webViewTest
//
//  Created by Sergey Sozinov on 20.11.2024.
//

import SwiftUI
import WebKit
import Mindbox

//@main
struct webViewTestApp: App {
//    let persistenceController = PersistenceController.shared
    let mindboxSdkConfig: MBConfiguration

    init() {
        // Логика инициализации Mindbox
        do {
            mindboxSdkConfig = try MBConfiguration(
                endpoint: "Test-staging.Test01",
                domain: "api-staging.mindbox.ru",
                subscribeCustomerIfCreated: true,
                shouldCreateCustomer: true
            )
            Mindbox.shared.initialization(configuration: mindboxSdkConfig)
            Mindbox.shared.getDeviceUUID { deviceUUID in
                print("Device UUID: \(deviceUUID)")
            }
        } catch {
            fatalError("Failed to initialize MBConfiguration: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentViewTest()
//                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}

struct ContentViewTest: View {
    @StateObject private var webViewModel = WebViewModelTest()

    var body: some View {
        VStack {
            WebViewContainer(webViewModel: webViewModel)
                .frame(maxHeight: .infinity)

            HStack {
                Button("SetCookie") {
                    webViewModel.setCookie()
                }
                Button("View") {
                    webViewModel.viewCookiesAndLocalStorage()
                }
            }
        }
    }
}

struct WebViewContainer: UIViewRepresentable {
    @ObservedObject var webViewModel: WebViewModelTest

    func makeUIView(context: Context) -> WKWebView {
        let preferences = WKPreferences()
        preferences.javaScriptEnabled = true

        // Настройка WKWebViewConfiguration
        let configuration = WKWebViewConfiguration()
        configuration.preferences = preferences
        let webView = WKWebView(frame: .zero, configuration: configuration)
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        webView.navigationDelegate = context.coordinator
        webViewModel.webView = webView

        loadInitialURL(webView)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    private func loadInitialURL(_ webView: WKWebView) {
        let url = URL(string: "https://personalization-test-site-staging.mindbox.ru/")!
        let request = URLRequest(url: url)
        webView.load(request)
    }

    func makeCoordinator() -> WebViewCoordinator {
        WebViewCoordinator(webViewModel: webViewModel)
    }
}

class WebViewCoordinator: NSObject, WKNavigationDelegate {
    private let webViewModel: WebViewModelTest

    init(webViewModel: WebViewModelTest) {
        self.webViewModel = webViewModel
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        print("Page started loading: \(webView.url?.absoluteString ?? "Unknown URL")")

    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        webViewModel.clearAllWebData(webView)
        webViewModel.setupWebViewForSync()
        print("Content started arriving for: \(webView.url?.absoluteString ?? "Unknown URL")")
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("Page finished loading: \(webView.url?.absoluteString ?? "Unknown URL")")
        webViewModel.viewCookiesAndLocalStorage()
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url?.absoluteString, url.contains("tracker.js") {
            print("Intercepted tracker.js: \(url)")
        }
        decisionHandler(.allow)
    }
}

class WebViewModelTest: ObservableObject {
    var webView: WKWebView?


    func clearAllWebData(_ webView: WKWebView) {
        let dataStore = WKWebsiteDataStore.default()
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()

        dataStore.removeData(ofTypes: dataTypes, modifiedSince: Date.distantPast) {
            print("All web data cleared")
        }
    }

    func setupWebViewForSync() {
        guard let webView = webView else { return }

        Mindbox.shared.getDeviceUUID { uuid in
            guard !uuid.isEmpty else {
                print("Device UUID is empty or invalid")
                return
            }
            let script = """
            document.cookie = "mindboxDeviceUUID=\(uuid); path=/";
            window.localStorage.setItem('mindboxDeviceUUID', '\(uuid)');
        """
            webView.evaluateJavaScript(script) { result, error in
                if let error = error {
                    print("Error setting cookies and localStorage: \(error)")
                } else {
                    print("Cookies and localStorage set successfully: \(result ?? "nil")")
                }
            }
        }
    }

    func setCookie() {
        guard let webView = webView else { return }

        Mindbox.shared.getDeviceUUID { uuid in
            guard !uuid.isEmpty else {
                print("Device UUID is empty or invalid")
                return
            }

            let script = """
            document.cookie = "mindboxDeviceUUID=\(uuid); path=/";
            window.localStorage.setItem('mindboxDeviceUUID', '\(uuid)');
        """
            webView.evaluateJavaScript(script) { result, error in
                if let error = error {
                    print("Error setting cookies: \(error)")
                } else {
                    print("Cookies set successfully: \(result ?? "nil")")
                }
            }
        }
    }

    func viewCookiesAndLocalStorage() {
        guard let webView = webView else { return }

        let script = """
        JSON.stringify({
            cookies: document.cookie,
            localStorage: window.localStorage.getItem('mindboxDeviceUUID')
        })
    """
        webView.evaluateJavaScript(script) { result, error in
            if let error = error {
                print("Error retrieving cookies and localStorage: \(error)")
            } else {
                print("Cookies and LocalStorage: \(result ?? "nil")")
            }
        }
    }
}
