//
//  SettingsRequestParser.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 23.03.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

enum SettingsType: String {
    case notifications
    case application
}

enum SettingsRequestParser {

    private enum PayloadKey {
        static let target = "target"
    }

    static func parse(from message: BridgeMessage) -> SettingsType? {
        guard case .string(let typeString)? = message.payloadObject?[PayloadKey.target],
              !typeString.isEmpty else {
            return nil
        }
        return SettingsType(rawValue: typeString)
    }
}
