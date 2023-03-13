//
//  CustomFields.swift
//  Mindbox
//
//  Created by Igor Kandaurov on 06.05.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation

// MARK: - [String: Any] Codable

/// [String: Any] that conforms to Codable
public struct CodableDictionary: Codable {
    var value: JSON

    public init(_ value: [String: Any]) {
        self.value = JSON(value)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try container.decode(JSON.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }

    public enum CustomFieldsError: Error {
        case decodingError
    }
}

// MARK: - ExpressibleByDictionaryLiteral

extension CodableDictionary: ExpressibleByDictionaryLiteral {
    public typealias Key = String
    public typealias Value = Any

    public init(dictionaryLiteral elements: (String, Any)...) {
        let stringAny = elements.reduce(into: [:]) { $0[$1.0] = $1.1 }
        value = JSON(stringAny)
    }
}

// MARK: - Subscript

extension CodableDictionary {
    subscript(key: String) -> Any {
        get { return value[key] }
        set { try? value.merge(with: JSON([key: newValue])) }
    }
}

extension CodableDictionary {
    public func decode<T: Decodable>(to type: T.Type) -> T? {
        do {
            return try JSONDecoder().decode(type, from: try value.rawData())
        } catch {
            return nil
        }
    }
}
