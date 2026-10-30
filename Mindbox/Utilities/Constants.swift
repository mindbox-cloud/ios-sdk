//
//  Constants.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 29.03.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation

enum Constants {

    enum Background {

        static let removeDeprecatedEventsInterval = TimeInterval(7 * 24 * 60 * 60)

        static let refreshTaskInterval = TimeInterval(6 * 60 * 60)
        static let processingTaskInterval = TimeInterval(12 * 60 * 60)
    }

    enum Database {

        static let mombName = "MBDatabase"
        static let retryDeadline: TimeInterval = 60
    }

    enum Notification {

        static let mindBoxIdentifireKey = "uniqueKey"
        static let pushTokenKeepalive = "pushTokenKeepalive"
        static let configVersion = "configVersion"
        static let sessionCheckStartedAt = "sessionCheckStartedAt"
        static let startsNewSession = "startsNewSession"
    }

    enum Versions {
        static let webBridgeVersion = 1
        static let sdkVersionNumeric = 13
    }

    enum WebViewLocalState {
        static let suiteName = "cloud.Mindbox.webview.localState"
        static let defaultVersion = 1
        static let keyPrefix = "mb_"
    }

    enum WebViewBridgeJS {
        static let handlerName = "SdkBridge"
        static let bridgeFunction = "window.bridgeMessagesHandlers.emit"

        static func sendScript(json: String) -> String {
            let quoted: String
            if let data = try? JSONSerialization.data(withJSONObject: json, options: .fragmentsAllowed),
               let result = String(data: data, encoding: .utf8) {
                quoted = result
            } else {
                quoted = "\"\(json)\""
            }
            return "(()=>{try{\(bridgeFunction)(\(quoted));return!0}catch(_){return!1}})()"
        }

        static let bridgeReady = "ok"
        static let bridgeNoNativeHandler = "no-native-bridge"
        static let bridgeNoPageHandlers = "no-handlers"
        static let bridgeFunctionReadyCheck = "(() => {"
            + "const h = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.\(handlerName);"
            + "if (!h || typeof h.postMessage !== 'function') return '\(bridgeNoNativeHandler)';"
            + "if (typeof window.bridgeMessagesHandlers === 'undefined' || typeof window.bridgeMessagesHandlers.emit !== 'function') return '\(bridgeNoPageHandlers)';"
            + "return '\(bridgeReady)';"
            + "})()"
    }

    enum WebViewHTTPErrorJS {
        static let handlerName = "SdkHttpErrorMonitor"

        static let detectionScript = """
        (function () {
          if (window.__mbxHttpErrorMonitorInstalled) { return; }
          window.__mbxHttpErrorMonitorInstalled = true;
          var reported = {};
          window.addEventListener('error', function (e) {
            var target = e && e.target;
            if (!target || !target.tagName || !(target.src || target.href)) { return; }
            try {
              var url = String(target.src || target.href || '');
              if (!url || reported[url]) { return; }
              reported[url] = true;
              window.webkit.messageHandlers.\(handlerName).postMessage({
                type: 'httpError',
                url: url
              });
            } catch (_) {}
          }, true);
        })();
        """
    }

    enum Migration {

        static let sdkVersionCode = 0
    }
    
    enum InfoUpdateVersions {
        
        case infoUpdated
        
        case keepAlive
        
        var operation: Event.Operation {
            switch self {
            case .infoUpdated:
                .infoUpdated
            case .keepAlive:
                .keepAlive
            }
        }
    }
    
    enum WebView {
        static let timeoutSeconds = 7
    }

    enum EmbeddedBlock {
        static let readyTimeoutSeconds = 7

        static let answerTimeoutSeconds = 30

        static let revealAnimationDuration: TimeInterval = 0.25
    }

    enum MagicNumbers {
        static let daysToKeepInappShowTimes = 2
    }
    
    enum StoreMetadataKey: String {
        case infoUpdate  = "ApplicationInfoUpdatedVersion"
        case instanceId  = "ApplicationInstanceId"

        static let preserved: [String] = [ Self.infoUpdate.rawValue, Self.instanceId.rawValue ]
    }
}
