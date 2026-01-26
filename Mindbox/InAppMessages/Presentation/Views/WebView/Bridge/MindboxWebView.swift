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
        userAgent: String
    ) {
        let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)

        let contentController = WKUserContentController()

        let sdkBridgeParamsObjectString = Self.buildSdkBridgeParams(
            params: params,
            persistenceStorage: persistenceStorage
        )

        let jsObserver: String = """
        (function () {
            // JS -> iOS: initial handshake
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.SdkBridge) {
                window.webkit.messageHandlers.SdkBridge.postMessage({
                    action: 'userAgent',
                    data: navigator.userAgent
                });
            }

            // Params from native
            window.sdkBridgeParams = \(sdkBridgeParamsObjectString);

            window.SdkBridge = {
                receiveParam: function (paramName) {
                    if (typeof paramName !== 'string') return;
                    return window.sdkBridgeParams[paramName.toLowerCase()];
                },

                // Explicit JS -> iOS channel
                send: function (action, data) {
                    if (!window.webkit || !window.webkit.messageHandlers || !window.webkit.messageHandlers.SdkBridge) {
                        return;
                    }
                    window.webkit.messageHandlers.SdkBridge.postMessage({
                        action: action,
                        data: data
                    });
                }
            };

            // iOS -> JS channel
            window.__nativeBridge = {
                receive: function (message) {
                    try {
                        if (!message || !message.action) return;

                        switch (message.action) {
                        case 'showText':
                            var text = '';
                            if (message.payload !== undefined && message.payload !== null) {
                                if (typeof message.payload === 'string') {
                                    text = message.payload;
                                } else {
                                    try {
                                        text = JSON.stringify(message.payload);
                                    } catch (_) {
                                        text = String(message.payload);
                                    }
                                }
                            }

                            var el = document.getElementById('__native_text');
                            if (!el) {
                                el = document.createElement('div');
                                el.id = '__native_text';
                                el.style.position = 'fixed';
                                el.style.left = '0';
                                el.style.right = '0';
                                el.style.bottom = '0';
                                el.style.padding = '12px';
                                el.style.background = 'rgba(0,0,0,0.8)';
                                el.style.color = 'white';
                                el.style.fontSize = '14px';
                                el.style.zIndex = '999999';
                                el.style.fontFamily = 'system-ui, -apple-system, sans-serif';
                                document.body.appendChild(el);
                            }

                            el.textContent = text;
                            break;

                        default:
                            console.log('Native message:', message);
                            window.SdkBridge.send('nativeMessage', message.action);
                            break;
                        }
                    } catch (e) {
                        console.error('Native bridge error:', e);
                        window.SdkBridge.send('nativeError', String(e));
                    }
                }
            };

            // Notify readiness
            window.SdkBridge.send('ready', null);
        })();
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
}
