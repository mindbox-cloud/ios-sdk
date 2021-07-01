//
//  CustomerAllFieldsResponse.swift
//  Mindbox
//
//  Created by Mikhail Plotnikov on 28.06.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

open class CustomerAllFieldsResponse: Decodable {
    public let status: CustomerAllFieldsTypeResponse?
    public let personalOffers: [PersonalOffersResponse]?
    public let balances: [BalanceResponse]?
    public let discountCards: [DiscountCardResponse]
    public let customer: CustomerResponse?
    public let promoAction: [PromoActionsResponse]?
    public let productList: [ProductListResponse]?
    public let retailOrderStatistics: Double?
}
