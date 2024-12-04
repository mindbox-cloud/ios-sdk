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

@Observable final class ViewModel {

    /// Synchronize deviceUUID
    func syncMindboxDeviceUUIDs(with webView: WKWebView) {
        Mindbox.shared.getDeviceUUID { uuid in
            guard !uuid.isEmpty else {
                Mindbox.logger.log(level: .error, message: "[WebView]: Device UUID is empty or invalid")
                return
            }

            let script = """
                document.cookie = "mindboxDeviceUUID=\(uuid); path=/";
                window.localStorage.setItem('mindboxDeviceUUID', '\(uuid)');
            """

            DispatchQueue.main.async {
                webView.evaluateJavaScript(script) { _, error in
                    if let error = error {
                        Mindbox.logger.log(level: .error, message: "[WebView]: Error setting cookies and localStorage: \(error)")
                    } else {
                        Mindbox.logger.log(level: .default, message: "[WebView]: Cookies and localStorage set successfully.")
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
            Mindbox.logger.log(level: .default, message: "[WebView]: All web data cleared")
        }
    }
}

// MARK: - Auxiliary functions for debugging

extension ViewModel {

    /// Use it to debug data after tracker initialize.
    /// For example add button for debug
    func viewCookiesAndLocalStorage(with webView: WKWebView) {
        print("\n" + #function)

        Mindbox.shared.getDeviceUUID { uuid in
            let message = "[WebView]: Mobile SDK UUID: \(uuid)"
            print(message)
            Mindbox.logger.log(level: .default, message: message)
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
                    Mindbox.logger.log(level: .error, message: message)
                } else {
                    let message = "[WebView]: Cookies and LocalStorage: \(result ?? "nil")"
                    print("Start===============")
                    print("Cookies and LocalStorage: \(result ?? "nil")")
                    print("===============End\n")
                    Mindbox.logger.log(level: .default, message: message)
                }
            }
        }
    }
}
