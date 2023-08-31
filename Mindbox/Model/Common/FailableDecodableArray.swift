//
//  FailableDecodableArray.swift
//  Mindbox
//
//  Created by vailence on 03.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

struct FailableDecodableArray<Element: Decodable & Equatable>: Decodable, Equatable {

    let elements: [Element]

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()

        var elements = [Element]()
        if let count = container.count {
            elements.reserveCapacity(count)
        }

        while !container.isAtEnd {
            if let element = try? container.decode(Element.self) {
                elements.append(element)
            } else {
                _ = try? container.decode(DummyCodable.self) // "Consumes" the failed element
            }
        }

        self.elements = elements
    }

    private struct DummyCodable: Decodable { }
}

struct FailableDecodable<Element: Decodable & Equatable>: Decodable, Equatable {
    let element: Element?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        element = try? container.decode(Element.self)
    }
}
