//
//  AddToProductList.swift
//  Mindbox
//
//  Created by Mikhail Plotnikov on 06.05.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

public class AddProductToList: Codable {
    public var product, productGroup: Product?
    public var pricePerItem: Double?

    public init(product: Product?, productGroup: Product?, pricePerItem: Double?) {
        self.product = product
        self.productGroup = productGroup
        self.pricePerItem = pricePerItem
    }
}
