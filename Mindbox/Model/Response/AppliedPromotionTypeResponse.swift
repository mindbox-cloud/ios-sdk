//
//  AppliedPromotionTypeResponse.swift
//  Mindbox
//
//  Created by lbr on 08.06.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

public enum AppliedPromotionTypeResponse: String, Decodable {
    case discount
    case correctionDiscount
    case deliveryDiscount
    case earnedBonusPoints
    case spentBonusPoints
    case issuedCoupon
    case message
    case preconditionMarker
}
