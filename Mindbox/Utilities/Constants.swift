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

        static let refreshTaskInterval = TimeInterval(6 * 60 * 60) // 6 hours
        static let processingTaskInterval = TimeInterval(12 * 60 * 60) // 12 hours
    }

    enum Database {

        static let mombName = "MBDatabase"
        static let retryDeadline: TimeInterval = 60
    }

    enum Notification {

        static let mindBoxIdentifireKey = "uniqueKey"
        static let pushTokenKeepalive = "pushTokenKeepalive"
    }

    /// Mobile configuration sdkVersion.
    enum Versions {
        static let webBridgeVersion = 1
        static let sdkVersionNumeric = 12
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

        static let bridgeFunctionReadyCheck = "(() => typeof window.bridgeMessagesHandlers !== 'undefined' && typeof window.bridgeMessagesHandlers.emit === 'function')()"
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

    /// Constants used for migration management.
    enum Migration {

        /// The current SDK version code used for comparison in migrations.
        static let sdkVersionCode = 0
    }
    
    /// Constants helper. Operations used for update push-notifications data on the server
    enum InfoUpdateVersions {
        
        /// Operation for the “application info updated” event.
        case infoUpdated
        
        /// Operation for the “application keep-alive” event.
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
        /// How long an embedded block waits for the page to report its content before collapsing.
        ///
        /// Its own budget rather than the in-apps' one, even when the numbers agree: a block sits
        /// in the host's layout, and how long it holds that space is a product decision of its
        /// own, not a consequence of what a popup waits for.
        ///
        /// It covers strictly more than a popup's: the page has to load, boot its bridge, ask for
        /// its start payload, run its own pipeline — which includes waiting up to three seconds
        /// on a targeting answer before giving up on it — and only then report what it drew.
        /// Roughly 3s to load, 1s to boot, 3s of targeting, 3s to render, and slack.
        static let readyTimeoutSeconds = 12
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
