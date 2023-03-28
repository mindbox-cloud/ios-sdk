//
//  InAppOperationJSONModel.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 16.03.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

struct InappOperationJSONModel: Codable, Equatable, Hashable {
    static func == (lhs: InappOperationJSONModel, rhs: InappOperationJSONModel) -> Bool {
        lhs.viewProductCategory == rhs.viewProductCategory
    }
    
    let viewProductCategory: ViewProductCategory
}

struct ViewProductCategory: Codable, Equatable, Hashable {
    static func == (lhs: ViewProductCategory, rhs: ViewProductCategory) -> Bool {
        lhs.productCategory == rhs.productCategory
    }
    
    let productCategory: ProductCategory
}

struct ProductCategory: Codable, Equatable, Hashable {
    let ids: [String: String]
    
    enum CodingKeys: String, CodingKey {
        case ids
    }
    
    init(ids: [String: String]) {
        self.ids = ids
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let unprocessedIds = try container.decode([String: String].self, forKey: .ids)
        
        ids = unprocessedIds.reduce(into: [:]) { (result, keyValue) in
            result[keyValue.key] = keyValue.value.uppercased()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        let processedIds = ids.reduce(into: [:]) { (result, keyValue) in
            result[keyValue.key] = keyValue.value.uppercased()
        }
        
        try container.encode(processedIds, forKey: .ids)
    }
}
