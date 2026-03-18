//
//  HapticRequestParser.swift
//  Mindbox
//
//  Created by Sergei Semko on 3/18/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

enum HapticRequestParser {

    private enum PayloadKey {
        static let type = "type"
        static let style = "style"
        static let pattern = "pattern"
        static let time = "time"
        static let duration = "duration"
        static let intensity = "intensity"
        static let sharpness = "sharpness"
    }

    private enum TypeName {
        static let selection = "selection"
        static let impact = "impact"
        static let notification = "notification"
        static let pattern = "pattern"
    }

    private enum Default {
        static let type = TypeName.selection
        static let impactStyle = "medium"
        static let notificationStyle = "success"
    }

    // MARK: - Public

    static func parse(from message: BridgeMessage) -> HapticRequest {
        let dict = extractPayloadDict(from: message)

        let type: String
        if case .string(let s) = dict[PayloadKey.type] {
            type = s
        } else {
            type = Default.type
        }

        switch type {
        case TypeName.selection:
            return .selection

        case TypeName.impact:
            let styleString: String
            if case .string(let s) = dict[PayloadKey.style] {
                styleString = s
            } else {
                styleString = Default.impactStyle
            }
            let style = HapticRequest.ImpactStyle(rawValue: styleString) ?? .medium
            return .impact(style)

        case TypeName.notification:
            let styleString: String
            if case .string(let s) = dict[PayloadKey.style] {
                styleString = s
            } else {
                styleString = Default.notificationStyle
            }
            let style = HapticRequest.NotificationStyle(rawValue: styleString) ?? .success
            return .notification(style)

        case TypeName.pattern:
            let events = extractPatternEvents(from: dict)
            return .pattern(events)

        default:
            return .selection
        }
    }

    // MARK: - Payload extraction

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

    private static func extractPatternEvents(from dict: [String: JSONValue]) -> [HapticPatternEvent] {
        guard case .array(let array) = dict[PayloadKey.pattern] else { return [] }

        return array.compactMap { item -> HapticPatternEvent? in
            guard case .object(let obj) = item else { return nil }
            return HapticPatternEvent(
                time: obj[PayloadKey.time]?.doubleValue ?? 0,
                duration: obj[PayloadKey.duration]?.doubleValue ?? 0,
                intensity: obj[PayloadKey.intensity]?.doubleValue ?? 1.0,
                sharpness: obj[PayloadKey.sharpness]?.doubleValue ?? 0.5
            )
        }
    }
}
