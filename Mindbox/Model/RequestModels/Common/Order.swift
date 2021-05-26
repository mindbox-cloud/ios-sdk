//
//  Order.swift
//  Mindbox
//
//  Created by Mikhail Plotnikov on 06.05.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

// MARK: - Order
public class Order: Codable {
    public var ids: IDS
    public var cashdesk: Area?
    public var deliveryCost: Double?
    public var customFields: CustomFields?
    public var area: Area?
    public var totalPrice: Double?
    public var discounts: [Discount]?
    public var lines: [Line]
    public var email, mobilePhone: String

    public init(
        ids: IDS,
        cashdesk: Area?,
        deliveryCost: Double?,
        customFields: CustomFields?,
        area: Area?,
        totalPrice: Double?,
        discounts: [Discount]?,
        lines: [Line],
        email: String,
        mobilePhone: String
    ) {
        self.ids = ids
        self.cashdesk = cashdesk
        self.deliveryCost = deliveryCost
        self.customFields = customFields
        self.area = area
        self.totalPrice = totalPrice
        self.discounts = discounts
        self.lines = lines
        self.email = email
        self.mobilePhone = mobilePhone
    }
    
    // MARK: - IDS
    public class IDS: Codable {
        public var mindboxId: Int?
        public var websiteId: String?

        public init(mindboxId: Int?, websiteId: String?) {
            self.mindboxId = mindboxId
            self.websiteId = websiteId
        }
    }
}
