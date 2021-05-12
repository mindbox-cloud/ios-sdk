//
//  ProductList.swift
//  Mindbox
//
//  Created by Mikhail Plotnikov on 06.05.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

// MARK: - ProductList

public class ProductList: Codable {
    public let product, productGroup: Product?
    public let count, pricePerItem, priceOfLine: Double?

    public init(product: Product?, productGroup: Product?, count: Double, pricePerItem: Double?, priceOfLine: Double?) {
        self.product = product
        self.productGroup = productGroup
        self.count = count
        self.pricePerItem = pricePerItem
        self.priceOfLine = priceOfLine
    }
}
