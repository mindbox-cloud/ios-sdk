//
//  IDS.swift
//  Mindbox
//
//  Created by Ihor Kandaurov on 19.05.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

// MARK: - IDS

public struct IDS: Codable {
    public typealias DictionaryType = [String: String]

    private var value: Dictionary<String, String> = [:]

    public init(_ value: [String: String]? = nil, mindboxId: Int? = nil) {
        self.value = value ?? [:]
        if let mindboxId = mindboxId {
            self.value["mindboxId"] = String(mindboxId)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try container.decode([String: String].self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }

    public enum CustomFieldsError: Error {
        case decodingError
    }
}

// MARK: - Collection

extension IDS: Collection {
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

    public func index(after i: IDS.DictionaryType.Index) -> IDS.DictionaryType.Index {
        return value.index(after: i)
    }
}

// MARK: - ExpressibleByDictionaryLiteral

extension IDS: ExpressibleByDictionaryLiteral {
    public typealias Key = String
    public typealias Value = String

    public init(dictionaryLiteral elements: (String, String)...) {
        value = elements.reduce(into: [:]) { $0[$1.0] = $1.1 }
    }
}

// MARK: - Subscript

extension IDS {
    subscript(key: String) -> String? {
        get { return value[key] }
        set { value[key] = newValue }
    }
}
