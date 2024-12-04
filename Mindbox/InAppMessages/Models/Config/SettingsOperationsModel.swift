//
//  SettingsOperationsModel.swift
//  Mindbox
//
//  Created by Sergei Semko on 9/12/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation

extension Settings {
    struct SettingsOperations: Decodable, Equatable {

        let viewProduct: Operation?
        let viewCategory: Operation?
        let setCart: Operation?

        enum CodingKeys: CodingKey {
            case viewProduct
            case viewCategory
            case setCart
        }

        struct Operation: Decodable, Equatable {
            let systemName: String
        }
    }
}

extension Settings.SettingsOperations {
    init(from decoder: any Decoder) throws {
        let container: KeyedDecodingContainer = try decoder.container(keyedBy: CodingKeys.self)
        self.viewProduct = try? container.decodeIfPresent(Operation.self, forKey: .viewProduct)
        self.viewCategory = try? container.decodeIfPresent(Operation.self, forKey: .viewCategory)
        self.setCart = try? container.decodeIfPresent(Operation.self, forKey: .setCart)

        if viewProduct == nil && viewCategory == nil && setCart == nil {
            // Will never be caught because of `try?` in `Settings.init`
            throw DecodingError.dataCorruptedError(forKey: .viewProduct, in: container, debugDescription: "The `operation` type could not be decoded because all operations are nil")
        }
    }
}
