//
//  DiscountTypeRequest.swift
//  Mindbox
//
//  Created by Ihor Kandaurov on 21.05.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

public enum DiscountTypeRequest: String, Encodable {
    case promoCode
    case externalPromoAction
}
