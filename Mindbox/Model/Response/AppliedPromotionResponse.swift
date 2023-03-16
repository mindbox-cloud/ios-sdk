//
//  AppliedPromotionResponse.swift
//  Mindbox
//
//  Created by lbr on 08.06.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation

open class AppliedPromotionResponse: Codable {
    public let type: AppliedPromotionTypeResponse?
    public let coupon: CouponResponse?
    public let promotion: PromotionResponse?
    public let limits: [LimitResponse]?
    public let groupingKey: String?
    public let balanceType: BalanceTypeReponse?
    public let amount: Double?
    public let expirationDateTimeUtc: DateTime?
    public let spentBonusPointsAmount: Double?
    public let issuedCoupon: CouponResponse?
}
