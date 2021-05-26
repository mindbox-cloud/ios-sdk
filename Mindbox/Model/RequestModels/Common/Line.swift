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
    public var minPricePerItem, costPricePerItem: Double?
    public var customFields: CustomFields?
    public var basePricePerItem, quantity: Double?
    public var quantityType: String?
    public var discountedPricePerLine: Double?
    public var lineId: String?
    public var lineNumber: Int?
    public var discounts: [Discount]?
    public var product: Product?

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
