//
//  OperationResponse.swift
//  Mindbox
//
//  Created by Ihor Kandaurov on 28.05.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

open class OperationResponse: OperationResponseType {
    public var status: Status
    public let customer: CustomerResponse?
    public let productList: [ProductListResponse]?
    public let productListItems: ProductListItemsResponse?
    public let recommendations: [RecommendationResponse]?
    public let customerSegmentations: [CustomerSegmentationResponse]?
    public let setProductCountInList: ProductListResponse?
    public let promoCode: PromoCodeResponse?
    public let personalOffers: [PersonalOffersResponse]?
    public let balances: [BalanceResponse]?
    public let discountCards: [DiscountCardResponse]?
    // TODO: MOBILE-303 — rename to `promoActions` in 3.0: the API key is plural,
    // the singular property name is a source-breaking legacy we keep until a major release.
    public let promoAction: [PromoActionsResponse]?
    public let retailOrderStatistics: RetailOrderStatisticsResponse?

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        status = try container.decode(Status.self, forKey: .status)
        customer = try container.decodeIfPresent(CustomerResponse.self, forKey: .customer)
        if let list = try? container.decodeIfPresent([ProductListResponse].self, forKey: .productList) {
            productList = list
            productListItems = nil
        } else {
            productListItems = try container.decodeIfPresent(ProductListItemsResponse.self, forKey: .productList)
            productList = nil
        }
        recommendations = try container.decodeIfPresent([RecommendationResponse].self, forKey: .recommendations)
        customerSegmentations = try container.decodeIfPresent([CustomerSegmentationResponse].self, forKey: .customerSegmentations)
        setProductCountInList = try container.decodeIfPresent(ProductListResponse.self, forKey: .setProductCountInList)
        promoCode = try container.decodeIfPresent(PromoCodeResponse.self, forKey: .promoCode)
        personalOffers = try container.decodeIfPresent([PersonalOffersResponse].self, forKey: .personalOffers)
        balances = try container.decodeIfPresent([BalanceResponse].self, forKey: .balances)
        discountCards = try container.decodeIfPresent([DiscountCardResponse].self, forKey: .discountCards)
        promoAction = try container.decodeIfPresent([PromoActionsResponse].self, forKey: .promoActions)
        retailOrderStatistics = try container.decodeIfPresent(RetailOrderStatisticsResponse.self, forKey: .retailOrderStatistics)
    }

    // `encode(to:)` must stay in sync with `Keys` — the compiler can't synthesize it
    // from this enum (it isn't named `CodingKeys`), and synthesized encoding by
    // property names is exactly what hid the promoAction/promoActions mismatch.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(customer, forKey: .customer)
        try container.encodeIfPresent(productList, forKey: .productList)
        try container.encodeIfPresent(productListItems, forKey: .productListItems)
        try container.encodeIfPresent(recommendations, forKey: .recommendations)
        try container.encodeIfPresent(customerSegmentations, forKey: .customerSegmentations)
        try container.encodeIfPresent(setProductCountInList, forKey: .setProductCountInList)
        try container.encodeIfPresent(promoCode, forKey: .promoCode)
        try container.encodeIfPresent(personalOffers, forKey: .personalOffers)
        try container.encodeIfPresent(balances, forKey: .balances)
        try container.encodeIfPresent(discountCards, forKey: .discountCards)
        try container.encodeIfPresent(promoAction, forKey: .promoActions)
        try container.encodeIfPresent(retailOrderStatistics, forKey: .retailOrderStatistics)
    }

    enum Keys: String, CodingKey {
        case status
        case customer
        case productList
        // Encode-only: both productList shapes decode from the `productList` wire key,
        // but have always re-encoded under their own property names — kept that way
        // so the bridge payload only gains promoActions, nothing else moves.
        // TODO: MOBILE-303 — drop this key in 3.0 and re-encode both shapes under
        // `productList`, making the bridge payload fully wire-faithful (as on Android).
        case productListItems
        case recommendations
        case customerSegmentations
        case setProductCountInList
        case promoCode
        case personalOffers
        case balances
        case discountCards
        // The API sends the plural key; the `promoAction` property keeps its
        // historical singular name because renaming it would break the public SDK surface.
        case promoActions
        case retailOrderStatistics
    }
}

public extension OperationResponse {
    func createJSON() -> String {
        guard
            let jsonData = try? JSONEncoder().encode(self),
            let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
                    """
                    {
                        type: "InternalError",
                        data: {
                            errroKey: "null",
                            errroName: "JSON encoding error",
                            errorMessage: "Unable to convert Data to JSON",
                        }
                    }
                    """
        }
        return jsonString
    }
}
