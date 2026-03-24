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
        let dict = extractPayloadDict(from: message)
        guard case .string(let typeString) = dict[PayloadKey.target], !typeString.isEmpty else {
            return nil
        }
        return SettingsType(rawValue: typeString)
    }

    private static func extractPayloadDict(from message: BridgeMessage) -> [String: JSONValue] {
        if case .string(let str) = message.payload,
           let data = str.data(using: .utf8),
           let dict = try? JSONDecoder().decode([String: JSONValue].self, from: data) {
            return dict
        }
        if case .object(let dict) = message.payload {
            return dict
        }
        return [:]
    }
}
