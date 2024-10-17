//
//  UnknownDecodable.swift
//  Mindbox
//
//  Created by Mikhail Plotnikov on 08.07.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

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

                let error = MindboxError(InternalError(errorKey: .parsing, reason: "No match with value \(parsed). Set to .unknown", suggestion: "Add an .\(parsed) case"))
                Logger.error(error.asLoggerError())
            } else {
                let error = MindboxError.internalError(.init(errorKey: .parsing, reason: "No match with value \(parsed). Enum doesn’t have .unknown case", suggestion: "Add an .unknown case"))
                Logger.error(error.asLoggerError())
                throw error
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
