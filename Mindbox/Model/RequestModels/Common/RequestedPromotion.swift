//
//  RequestedPromotion.swift
//  Mindbox
//
//  Created by Mikhail Plotnikov on 06.05.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

// MARK: - RequestedPromotion

public class RequestedPromotion: Codable {
    public let type: String
    public let promotion: Area?
    public let coupon: Coupon?
    public let amount: Double?

    public init(type: String, promotion: Area, coupon: Coupon?, amount: Double) {
        self.type = type
        self.promotion = promotion
        self.coupon = coupon
        self.amount = amount
    }
}
