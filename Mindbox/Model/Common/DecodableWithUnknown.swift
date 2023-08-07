//
//  DecodableWithUnknown.swift
//  Mindbox
//
//  Created by vailence on 07.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

protocol DecodableWithUnknown: RawRepresentable, Decodable where RawValue: Decodable {
    static var unknownCase: Self { get }
}

extension DecodableWithUnknown where Self: RawRepresentable, RawValue == String {
    static var unknownCase: Self {
        return Self(rawValue: "unknown")!
    }
}

extension Decodable where Self: DecodableWithUnknown {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(RawValue.self)
        self = Self(rawValue: rawValue) ?? Self.unknownCase
    }
}
