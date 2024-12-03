//
//  MainViewModel.swift
//  Example
//
//  Created by Дмитрий Ерофеев on 29.03.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Observation
import WebKit
import Mindbox
import MindboxLogger

@Observable final class ViewModel {

    weak var webView: WKWebView?

    func setWebView(_ webView: WKWebView) {
        self.webView = webView
    }

    /// Synchronize deviceUUID
    func syncMindboxDeviceUUIDs() {
        Mindbox.shared.getDeviceUUID { [weak webView] uuid in
            guard let webView, !uuid.isEmpty else {
                Logger.common(message: "[WebView]: Device UUID is empty or invalid", level: .error)
                return
            }

            let script = """
                document.cookie = "mindboxDeviceUUID=\(uuid); path=/";
                window.localStorage.setItem('mindboxDeviceUUID', '\(uuid)');
            """

            DispatchQueue.main.async {
                webView.evaluateJavaScript(script) { _, error in
                    if let error = error {
                        Logger.common(message: "[WebView]: Error setting cookies and localStorage: \(error)", level: .error)
                    } else {
                        Logger.common(message: "[WebView]: Cookies and localStorage set successfully.")
                    }
                }
            }

        }
    }

    func setCookie() {
        Mindbox.shared.getDeviceUUID { [weak webView] uuid in
            guard let webView, !uuid.isEmpty else {
                Logger.common(message: "[WebView]: Device UUID is empty or invalid", level: .error)
                return
            }

            let script = """
            document.cookie = "mindboxDeviceUUID=\(uuid); path=/";
            window.localStorage.setItem('mindboxDeviceUUID', '\(uuid)');
            """

            DispatchQueue.main.async {
                webView.evaluateJavaScript(script) { _, error in
                    if let error = error {
                        Logger.common(message: "[WebView]: Error setting cookies: \(error)", level: .error)
                    } else {
                        Logger.common(message: "[WebView]: Cookies set successfully.")
                    }
                }
            }
        }
    }

    /// Use this method to clear WebView data
    func clearAllWebsiteData() {
        let dataStore = WKWebsiteDataStore.default()
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()

        dataStore.removeData(ofTypes: dataTypes, modifiedSince: Date.distantPast) {
            Logger.common(message: "[WebView]: All web data cleared")
        }
    }
}

// MARK: - Auxiliary functions for debugging

extension ViewModel {

    /// Use it to debug data after tracker initialize.
    /// For example add button for debug
    func viewCookiesAndLocalStorage() {
        guard let webView = webView else { return }
        print("\n" + #function)

        Mindbox.shared.getDeviceUUID { uuid in
            let message = "[WebView]: Mobile SDK UUID: \(uuid)"
            print(message)
            Logger.common(message: message)
        }

        let script = """
                JSON.stringify({
                    cookies: document.cookie || "No cookies found",
                    localStorage: window.localStorage.getItem('mindboxDeviceUUID') || "No value found"
                })
            """

        DispatchQueue.main.async {
            webView.evaluateJavaScript(script) { result, error in
                if let error = error {
                    let message = "[WebView]: Error retrieving cookies and localStorage: \(error)"
                    print(message)
                    Logger.common(message: message, level: .error)
                } else {
                    let message = "[WebView]: Cookies and LocalStorage: \(result ?? "nil")"
                    print("Start===============")
                    print("Cookies and LocalStorage: \(result ?? "nil")")
                    print("===============End\n")
                    Logger.common(message: message)
                }
            }
        }
    }
}
