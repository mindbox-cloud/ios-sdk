//
//  ItemResponse.swift
//  Mindbox
//
//  Created by lbr on 08.06.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation

open class ItemResponse: Codable {
    public let product: ItemProductResponse?
    public let basePricePerItem: Double?
    public let minPricePerItem: Double?
    public let priceForCustomer: Double?
    public let appliedPromotions: [AppliedPromotionResponse]?
    public let placeholders: [PlaceholderResponse]?
}
