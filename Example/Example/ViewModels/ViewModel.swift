//
//  MainViewModel.swift
//  Example
//
//  Created by Дмитрий Ерофеев on 29.03.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
import Mindbox
import Observation
import WebKit

@Observable final class ViewModel {

    var isLoading: Bool = false
    var errorMessage: String? = nil

    var webView: WKWebView?

    func setWebView(_ webView: WKWebView) {
        self.webView = webView
    }

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
            webView.evaluateJavaScript(script) { _, error in
                if let error = error {
                    print("Error setting cookies and localStorage: \(error)")
                } else {
                    print("Cookies and localStorage set successfully.")
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
            webView.evaluateJavaScript(script) { _, error in
                if let error = error {
                    print("Error setting cookies: \(error)")
                } else {
                    print("Cookies set successfully.")
                }
            }
        }
    }

    func viewCookiesAndLocalStorage() {
        guard let webView = webView else { return }

        let script = """
                JSON.stringify({
                    cookies: document.cookie || "No cookies found",
                    localStorage: window.localStorage.getItem('mindboxDeviceUUID') || "No value found"
                })
            """
        webView.evaluateJavaScript(script) { result, error in
            if let error = error {
                print("Error retrieving cookies and localStorage: \(error)")
            } else {
                print("\nStart===============")
                print("Cookies and LocalStorage: \(result ?? "nil")")
                print("===============End\n")
            }
        }
    }

//    var webView: WKWebView?

    var SDKVersion: String = ""
    var deviceUUID: String = ""
    var APNSToken: String = ""
    
    // https://developers.mindbox.ru/docs/ios-sdk-methods
    func setupData() {
        self.SDKVersion = Mindbox.shared.sdkVersion
        Mindbox.shared.getDeviceUUID { deviceUUID in
            DispatchQueue.main.async {
                self.deviceUUID = deviceUUID
            }
        }
        Mindbox.shared.getAPNSToken { APNSToken in
            DispatchQueue.main.async {
                self.APNSToken = APNSToken
            }
        }
    }
    
    // https://developers.mindbox.ru/docs/in-app-targeting-by-custom-operation
    func showInAppWithExecuteSyncOperation () {
        let json = """
        { "viewProduct":
            { "product":
                { "ids":
                    { "website": "1" }
                }
            }
        }
        """
        Mindbox.shared.executeSyncOperation(operationSystemName: "APIMethodForReleaseExampleIos", json: json) { result in
            switch result {
            case .success(let success):
                Mindbox.logger.log(level: .info, message: "\(success)")
            case .failure(let error):
                Mindbox.logger.log(level: .error, message: "\(error)")
            }
        }
    }
    
    // https://developers.mindbox.ru/docs/in-app-targeting-by-custom-operation
    func showInAppWithExecuteAsyncOperation () {
        let json = """
        { "viewProduct":
            { "product":
                { "ids":
                    { "website": "2" }
                }
            }
        }
        """
        Mindbox.shared.executeAsyncOperation(operationSystemName: "APIMethodForReleaseExampleIos", json: json)
    }
}
