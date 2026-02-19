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
    
    enum MagicNumbers {
        static let daysToKeepInappShowTimes = 2
    }
    
    enum StoreMetadataKey: String {
        case infoUpdate  = "ApplicationInfoUpdatedVersion"
        case instanceId  = "ApplicationInstanceId"

        static let preserved: [String] = [ Self.infoUpdate.rawValue, Self.instanceId.rawValue ]
    }
}
