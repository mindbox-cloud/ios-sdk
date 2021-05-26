//
//  Discount.swift
//  Mindbox
//
//  Created by Mikhail Plotnikov on 06.05.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

// MARK: - Discount

public class Discount: Codable {
    public var type: String?
    public var promoCode: DiscountPromoCode?
    public var amount: Double?
    public var externalPromoAction: Area?

    public init(type: String?, promoCode: DiscountPromoCode?, amount: Double?, externalPromoAction: Area?) {
        self.type = type
        self.promoCode = promoCode
        self.amount = amount
        self.externalPromoAction = externalPromoAction
    }
}
