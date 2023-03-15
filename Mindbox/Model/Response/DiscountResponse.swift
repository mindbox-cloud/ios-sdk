//
//  DiscountResponse.swift
//  Mindbox
//
//  Created by lbr on 08.06.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation

open class DiscountResponse: Codable {
    public let amount: Double?
    public let amountType: DiscountAmountTypeResponse?
}
