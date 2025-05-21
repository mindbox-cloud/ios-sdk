//
//  InAppOperationJSONModel.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 16.03.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

struct InappOperationJSONModel: Codable, Equatable, Hashable {
    let viewProduct: ViewProduct?
    let viewProductCategory: ViewProductCategory?

    static func == (lhs: InappOperationJSONModel, rhs: InappOperationJSONModel) -> Bool {
        lhs.viewProductCategory == rhs.viewProductCategory && lhs.viewProduct == rhs.viewProduct
    }

    init(viewProduct: ViewProduct? = nil, viewProductCategory: ViewProductCategory? = nil) {
        self.viewProduct = viewProduct
        self.viewProductCategory = viewProductCategory
    }
}

struct ViewProduct: Codable, Equatable, Hashable {
    let product: ProductCategory

    static func == (lhs: ViewProduct, rhs: ViewProduct) -> Bool {
        lhs.product == rhs.product
    }
}

struct ViewProductCategory: Codable, Equatable, Hashable {
    let productCategory: ProductCategory

    static func == (lhs: ViewProductCategory, rhs: ViewProductCategory) -> Bool {
        lhs.productCategory == rhs.productCategory
    }
}

struct ProductCategory: Codable, Equatable, Hashable {
    let ids: [String: String]

    enum CodingKeys: String, CodingKey {
        case ids
    }

    init(ids: [String: String]) {
        self.ids = ids
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawIds = try container.decode([String: CodableValue].self, forKey: .ids)

        var convertedIds = [String: String]()

        for (key, value) in rawIds {
            switch value {
            case .string(let stringValue):
                convertedIds[key] = stringValue
            case .int(let intValue):
                convertedIds[key] = String(intValue)
            case .double(let doubleValue):
                convertedIds[key] = String(doubleValue)
            }
        }

        self.ids = convertedIds
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.ids, forKey: .ids)
    }
    
    var firstProduct: DictionaryKeyValueModel? {
        if let firstProduct = ids.first {
            return DictionaryKeyValueModel(key: firstProduct.key, value: firstProduct.value)
        }
        
        return nil
    }
}

enum CodableValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            self = .double(doubleValue)
        } else {
            throw DecodingError.typeMismatch(
                CodableValue.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unsupported type"
                )
            )
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let stringValue):
            try container.encode(stringValue)
        case .int(let intValue):
            try container.encode(intValue)
        case .double(let doubleValue):
            try container.encode(doubleValue)
        }
    }
}
