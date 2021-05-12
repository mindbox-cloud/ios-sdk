//
//  Line.swift
//  Mindbox
//
//  Created by Mikhail Plotnikov on 06.05.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

// MARK: - Line

public class Line: Codable {
    public let minPricePerItem, costPricePerItem: Double?
    public let customFields: CustomFields?
    public let basePricePerItem, quantity: Double?
    public let quantityType: String?
    public let discountedPricePerLine: Double?
    public let lineId: String?
    public let lineNumber: Int?
    public let discounts: [Discount]?
    public let product: Product?

    public init(
        minPricePerItem: Double?,
        costPricePerItem: Double?,
        customFields: CustomFields?,
        basePricePerItem: Double,
        quantity: Double,
        quantityType: String?,
        discountedPricePerLine: Double?,
        lineId: String?,
        lineNumber: Int?,
        discounts: [Discount]?,
        product: Product?
    ) {
        self.minPricePerItem = minPricePerItem
        self.costPricePerItem = costPricePerItem
        self.customFields = customFields
        self.basePricePerItem = basePricePerItem
        self.quantity = quantity
        self.quantityType = quantityType
        self.discountedPricePerLine = discountedPricePerLine
        self.lineId = lineId
        self.lineNumber = lineNumber
        self.discounts = discounts
        self.product = product
    }
}
