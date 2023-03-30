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

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let processedIds = ids.mapValues { $0.uppercased() }
        try container.encode(processedIds, forKey: .ids)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let unprocessedIds = try container.decode([String: String].self, forKey: .ids)
        ids = unprocessedIds.mapValues { $0.uppercased() }
    }
}
