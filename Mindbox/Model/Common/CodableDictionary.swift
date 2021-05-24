//
//  CustomFields.swift
//  Mindbox
//
//  Created by Igor Kandaurov on 06.05.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

// MARK: - [String: Any] Codable

/// [String: Any] that conforms to Codable
public struct CodableDictionary: Codable {
    public typealias DictionaryType = [String: Any]

    private var value: Dictionary<String, Any>

    public init(_ value: [String: Any]) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let data = try container.decode(Data.self)
        guard let value = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            throw CustomFieldsError.decodingError
        }
        self.value = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let data = try JSONSerialization.data(withJSONObject: value, options: [])
        try container.encode(data)
    }

    public enum CustomFieldsError: Error {
        case decodingError
    }
}

// MARK: - Collection

extension CodableDictionary: Collection {
    public typealias Index = DictionaryType.Index
    public typealias Element = DictionaryType.Element

    public var startIndex: Index {
        return value.startIndex
    }

    public var endIndex: Index {
        return value.endIndex
    }

    public subscript(index: Index) -> Iterator.Element {
        return value[index]
    }

    public func index(after i: CustomFields.DictionaryType.Index) -> CustomFields.DictionaryType.Index {
        return value.index(after: i)
    }
}

// MARK: - ExpressibleByDictionaryLiteral

extension CodableDictionary: ExpressibleByDictionaryLiteral {
    public typealias Key = String
    public typealias Value = Any

    public init(dictionaryLiteral elements: (String, Any)...) {
        value = elements.reduce(into: [:]) { $0[$1.0] = $1.1 }
    }
}

// MARK: - Subscript

extension CodableDictionary {
    subscript(key: String) -> Any {
        get { return value[key] ?? [] }
        set { value[key] = newValue }
    }
}
