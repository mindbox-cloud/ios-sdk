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

    static func target(from message: BridgeMessage) -> String? {
        guard case .string(let target)? = message.payloadObject?[PayloadKey.target], !target.isEmpty else {
            return nil
        }
        return target
    }
}
