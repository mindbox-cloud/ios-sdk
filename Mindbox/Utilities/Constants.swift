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

        static let refreshTaskInterval = TimeInterval(2 * 60)
    }

    enum Database {

        static let mombName = "MBDatabase"
    }

    enum Notification {

        static let mindBoxIdentifireKey = "uniqueKey"
        static let pushTokenKeepalive = "pushTokenKeepalive"
    }

    /// Mobile configuration sdkVersion.
    enum Versions {

        static let sdkVersionNumeric = 11
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
}
