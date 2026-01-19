//
//  MindboxWebView.swift
//  Mindbox
//
//  Created by vailence on 17.10.2024.
//

import UIKit
import WebKit
import MindboxLogger

final class MindboxWebView: WKWebView {
    static let sdkBridgeHandlerName = "SdkBridge"

    init(
        params: [String: String]?,
        userAgent: String,
        messageHandler: WKScriptMessageHandler,
        navigationDelegate: WKNavigationDelegate?
    ) {
        let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)

        let contentController = WKUserContentController()
        contentController.add(messageHandler, name: Self.sdkBridgeHandlerName)

        let sdkBridgeParamsObjectString = Self.buildSdkBridgeParams(
            params: params,
            persistenceStorage: persistenceStorage
        )

        let jsObserver: String = """
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

        let userScript = WKUserScript(
            source: jsObserver,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )

        contentController.addUserScript(userScript)

        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        config.applicationNameForUserAgent = userAgent

        super.init(frame: .zero, configuration: config)

        self.navigationDelegate = navigationDelegate

        #if DEBUG
        if #available(iOS 16.4, *) {
            self.isInspectable = true
        }
        #endif
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static func buildSdkBridgeParams(
        params: [String: String]?,
        persistenceStorage: PersistenceStorage
    ) -> String {
        var mindboxParams: [String: String] = [
            "sdkVersion": Mindbox.shared.sdkVersion,
            "endpointId": persistenceStorage.configuration?.endpoint ?? "",
            "deviceUuid": persistenceStorage.deviceUUID ?? "",
            "sdkVersionNumeric": "\(Constants.Versions.sdkVersionNumeric)"
        ]

        if let params, !params.isEmpty {
            mindboxParams.merge(params) { _, new in new }
        }

        let lowercased = Dictionary(
            uniqueKeysWithValues: mindboxParams.map { ($0.key.lowercased(), $0.value) }
        )

        
        guard let data = try? JSONSerialization.data(withJSONObject: lowercased),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        
        return json
    }

    static func fetchHTMLContent(
        from urlString: String,
        completion: @escaping (String?) -> Void
    ) {
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }

        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.urlCache = nil

        let session = URLSession(configuration: config)
        let task = session.dataTask(with: url) { data, response, error in
            if error != nil {
                completion(nil)
                return
            }

            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                completion(nil)
                return
            }

            if let data,
               let html = String(data: data, encoding: .utf8) {
                completion(html)
            } else {
                completion(nil)
            }
        }

        task.resume()
    }
}
