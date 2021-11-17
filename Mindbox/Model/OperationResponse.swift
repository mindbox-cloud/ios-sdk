//
//  OperationResponse.swift
//  Mindbox
//
//  Created by Ihor Kandaurov on 28.05.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

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
        promoAction = try container.decodeIfPresent([PromoActionsResponse].self, forKey: .promoAction)
        retailOrderStatistics = try container.decodeIfPresent(RetailOrderStatisticsResponse.self, forKey: .retailOrderStatistics)
    }

    enum Keys: String, CodingKey {
        case status
        case customer
        case productList
        case recommendations
        case customerSegmentations
        case setProductCountInList
        case promoCode
        case personalOffers
        case balances
        case discountCards
        case promoAction
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
