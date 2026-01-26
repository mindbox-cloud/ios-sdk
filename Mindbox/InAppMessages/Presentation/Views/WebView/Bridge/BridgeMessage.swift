//
//  BridgeMessage.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 26.01.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

enum JSONValue: Codable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
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

    func encode(to encoder: Encoder) throws {
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
        if any is NSNull {
            self = .null
        } else if let value = any as? JSONValue {
            self = value
        } else if let value = any as? String {
            self = .string(value)
        } else if let value = any as? Bool {
            self = .bool(value)
        } else if let value = any as? Int {
            self = .int(value)
        } else if let value = any as? Int64 {
            self = .int(Int(value))
        } else if let value = any as? Double {
            self = .double(value)
        } else if let value = any as? Float {
            self = .double(Double(value))
        } else if let value = any as? [String: Any] {
            var object: [String: JSONValue] = [:]
            for (key, entry) in value {
                guard let jsonValue = JSONValue(any: entry) else { return nil }
                object[key] = jsonValue
            }
            self = .object(object)
        } else if let value = any as? [Any] {
            var array: [JSONValue] = []
            array.reserveCapacity(value.count)
            for entry in value {
                guard let jsonValue = JSONValue(any: entry) else { return nil }
                array.append(jsonValue)
            }
            self = .array(array)
        } else {
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

public struct BridgeMessage: Codable {
    enum MessageType: String, Codable {
        case request
        case response
        case error
    }

    let version: Int
    let type: MessageType
    let action: String
    let payload: JSONValue?
    let id: UUID
    let timestamp: Int64

    init(
        version: Int = 1,
        type: MessageType,
        action: String,
        payload: JSONValue?,
        id: UUID = UUID(),
        timestamp: Int64 = BridgeMessage.currentTimestampMs()
    ) {
        self.version = version
        self.type = type
        self.action = action
        self.payload = payload
        self.id = id
        self.timestamp = timestamp
    }

    init?(
        version: Int = 1,
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

        self.version = version
        self.type = type
        self.action = action
        self.id = id
        self.timestamp = timestamp
    }

    var payloadAny: Any? {
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

    static func currentTimestampMs() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }
}
