//
//  Item.swift
//  Mindbox
//
//  Created by Mikhail Plotnikov on 06.05.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

// MARK: - Item

public class Item: Codable {
    public var product: Product?
    public var basePricePerItem: Double
    public var minPricePerItem: Double?
    public var requestedPromotions: [RequestedPromotion]

    public init(
        product: Product?,
        basePricePerItem: Double,
        minPricePerItem: Double?,
        requestedPromotions: [RequestedPromotion]
    ) {
        self.product = product
        self.basePricePerItem = basePricePerItem
        self.minPricePerItem = minPricePerItem
        self.requestedPromotions = requestedPromotions
    }
}
