//
//  BridgeMessage.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 26.01.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

@_spi(Internal)
public enum JSONValue: Codable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
        } else if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            self = .double(doubleValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let objectValue = try? container.decode([String: JSONValue].self) {
            self = .object(objectValue)
        } else if let arrayValue = try? container.decode([JSONValue].self) {
            self = .array(arrayValue)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported JSON value"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    init?(any: Any?) {
        guard let any else {
            return nil
        }
        switch any {
        case is NSNull:
            self = .null
        case let value as JSONValue:
            self = value
        case let value as String:
            self = .string(value)
        case let value as Bool:
            self = .bool(value)
        case let value as Int:
            self = .int(value)
        case let value as Int64:
            self = .int(Int(value))
        case let value as Double:
            self = .double(value)
        case let value as Float:
            self = .double(Double(value))
        case let value as [String: Any]:
            var object: [String: JSONValue] = [:]
            for (key, entry) in value {
                guard let jsonValue = JSONValue(any: entry) else { return nil }
                object[key] = jsonValue
            }
            self = .object(object)
        case let value as [Any]:
            var array: [JSONValue] = []
            array.reserveCapacity(value.count)
            for entry in value {
                guard let jsonValue = JSONValue(any: entry) else { return nil }
                array.append(jsonValue)
            }
            self = .array(array)
        default:
            return nil
        }
    }

    var anyValue: Any? {
        switch self {
        case .string(let value):
            return value
        case .int(let value):
            return value
        case .double(let value):
            return value
        case .bool(let value):
            return value
        case .object(let value):
            return value.mapValues { $0.containerValue }
        case .array(let value):
            return value.map { $0.containerValue }
        case .null:
            return nil
        }
    }

    private var containerValue: Any {
        anyValue ?? NSNull()
    }
}

@_spi(Internal)
public struct BridgeMessage: Codable {
    public enum MessageType: String, Codable {
        case request
        case response
        case error
    }

    enum Action {
        static let close = "close"
        static let `init` = "init"
        static let click = "click"
        static let hide = "hide"
        static let log = "log"
        static let userAgent = "userAgent"
        static let ready = "ready"
        static let asyncOperation = "asyncOperation"
        static let syncOperation = "syncOperation"

        /// Actions that send their own bridge responses (no auto-response from dispatcher)
        static let deferredActions: Set<String> = [ready, asyncOperation, syncOperation]
    }

<<<<<<< semko/MOBILEWEBVIEW-54
    enum CodingKeys: String, CodingKey {
        case version, type, action, payload, id, timestamp
    }

=======
>>>>>>> mission/webView-inApp
    public let version: Int
    public let type: MessageType
    public let action: String
    public let payload: JSONValue?
    public let id: UUID
    public let timestamp: Int64

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(type, forKey: .type)
        try container.encode(action, forKey: .action)

        // JS bridge protocol requires payload as a JSON string (JS does JSON.parse(message.payload))
        if let payload {
            switch payload {
            case .string(let value):
                try container.encode(value, forKey: .payload)
            case .null:
                try container.encodeNil(forKey: .payload)
            default:
                if let data = try? JSONEncoder().encode(payload),
                   let str = String(data: data, encoding: .utf8) {
                    try container.encode(str, forKey: .payload)
                } else {
                    try container.encode("", forKey: .payload)
                }
            }
        } else {
            try container.encodeNil(forKey: .payload)
        }

        // JS generates lowercase UUIDs; Map lookup is case-sensitive
        try container.encode(id.uuidString.lowercased(), forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
    }

    public init(
        type: MessageType,
        action: String,
        payload: JSONValue?,
        id: UUID = UUID(),
        timestamp: Int64 = BridgeMessage.currentTimestampMs()
    ) {
        self.version = Constants.Versions.webBridgeVersion
        self.type = type
        self.action = action
        self.payload = payload
        self.id = id
        self.timestamp = timestamp
    }

    init?(
        type: MessageType,
        action: String,
        payload: Any?,
        id: UUID = UUID(),
        timestamp: Int64 = BridgeMessage.currentTimestampMs()
    ) {
        if payload == nil {
            self.payload = nil
        } else if let jsonPayload = JSONValue(any: payload) {
            self.payload = jsonPayload
        } else {
            return nil
        }

        self.version = Constants.Versions.webBridgeVersion
        self.type = type
        self.action = action
        self.id = id
        self.timestamp = timestamp
    }

    public var payloadAny: Any? {
        payload?.anyValue
    }

    static func from(body: Any) -> BridgeMessage? {
        if let data = body as? Data {
            return try? JSONDecoder().decode(BridgeMessage.self, from: data)
        }
        if let jsonString = body as? String,
           let data = jsonString.data(using: .utf8) {
            return try? JSONDecoder().decode(BridgeMessage.self, from: data)
        }
        if JSONSerialization.isValidJSONObject(body),
           let data = try? JSONSerialization.data(withJSONObject: body) {
            return try? JSONDecoder().decode(BridgeMessage.self, from: data)
        }
        return nil
    }

    func jsonString() -> String? {
        guard let data = try? JSONEncoder().encode(self),
              let json = String(data: data, encoding: .utf8) else {
            return nil
        }
        return json
    }

    public static func currentTimestampMs() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }

    func prettyPayloadDescription() -> String {
        guard let payload = payload else {
            return "nil"
        }

        // Helper to format JSON with pretty print
        func prettyJSON(from data: Data) -> String? {
            guard let jsonObject = try? JSONSerialization.jsonObject(with: data),
                  let prettyData = try? JSONSerialization.data(
                    withJSONObject: jsonObject,
                    options: [.prettyPrinted, .sortedKeys]
                  ),
                  let prettyString = String(data: prettyData, encoding: .utf8) else {
                return nil
            }
            return prettyString
        }

        switch payload {
        case .string(let stringValue):
            // If it's a JSON string, try to parse and pretty print it
            if let data = stringValue.data(using: .utf8),
               let pretty = prettyJSON(from: data) {
                return pretty
            }
            return stringValue

        case .object, .array:
            // Serialize JSONValue to pretty JSON
            if let data = try? JSONEncoder().encode(payload),
               let pretty = prettyJSON(from: data) {
                return pretty
            }
            return String(describing: payloadAny)

        default:
            return String(describing: payloadAny)
        }
    }
}
