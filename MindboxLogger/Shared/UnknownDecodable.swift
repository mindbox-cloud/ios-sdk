//
//  UnknownDecodable.swift
//  MindboxLogger
//
//  Created by vailence on 28.06.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

public enum UnknownDecodableError: Error {
    case unknownValue
}

public protocol UnknownDecodable: Decodable {}

public typealias UnknownCodable = Encodable & UnknownDecodable

public extension UnknownDecodable where Self: RawRepresentable, Self.RawValue == String {
    init(from decoder: Decoder) throws {
        let unknownCase = Self(rawValue: "unknown")
        do {
            let parsed = try decoder.singleValueContainer().decode(RawValue.self)
            let value = Self(rawValue: parsed)
            if let value = value {
                self = value
            } else if let unknownCase = unknownCase {
                self = unknownCase
            } else {
                throw UnknownDecodableError.unknownValue
            }
        } catch {
            if let unknownCase = unknownCase {
                self = unknownCase
            } else {
                Logger.common(message: error.localizedDescription, level: .error)
                throw error
            }
        }
    }
}
