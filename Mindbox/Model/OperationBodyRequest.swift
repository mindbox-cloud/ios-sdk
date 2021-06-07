//
//  OperationBodyRequest.swift
//  Mindbox
//
//  Created by Ihor Kandaurov on 19.05.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

open class OperationBodyRequest: OperationBodyRequestType {
    public var customAction: CustomerActionRequest?
    public var pointOfContact: String?
    public var segmentations: [SegmentationRequest]?
    public var customer: CustomerRequest?
    public var referencedCustomer: CustomerRequest?
    public var order: OrderRequest?
    public var discountCard: DiscountCardRequest?
    public var promoCode: PromoCodeRequest?
    public var viewProductCategory: ViewProductCategoryRequest?
    public var viewProduct: ViewProductRequest?
    public var productList: CatalogProductListRequest?
    public var setProductCountInList: ProductListRequest?
    public var addProductToList: ProductListRequest?
    public var removeProductFromList: ProductListRequest?
    /** This field used for product and will be serialized as productList */
    public var productListItems: [ProductListRequest]?

    public init() { }

    open func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(customAction, forKey: .customAction)
        try container.encodeIfPresent(pointOfContact, forKey: .pointOfContact)
        try container.encodeIfPresent(addProductToList, forKey: .addProductToList)
        try container.encodeIfPresent(segmentations, forKey: .segmentations)
        try container.encodeIfPresent(customer, forKey: .customer)
        try container.encodeIfPresent(order, forKey: .order)
        try container.encodeIfPresent(discountCard, forKey: .discountCard)
        try container.encodeIfPresent(removeProductFromList, forKey: .removeProductFromList)
        try container.encodeIfPresent(setProductCountInList, forKey: .setProductCountInList)
        if productList != nil {
            try container.encodeIfPresent(productList, forKey: .productList)
        } else if productListItems != nil {
            try container.encodeIfPresent(productListItems, forKey: .productList)
        }
        try container.encodeIfPresent(promoCode, forKey: .promoCode)
        try container.encodeIfPresent(viewProductCategory, forKey: .viewProductCategory)
        try container.encodeIfPresent(viewProduct, forKey: .viewProduct)
    }

    private enum CodingKeys: String, CodingKey {
        case customAction
        case pointOfContact
        case addProductToList
        case segmentations
        case customer
        case order
        case discountCard
        case removeProductFromList
        case setProductCountInList
        case productList
        case promoCode
        case viewProductCategory
        case viewProduct
        case referencedCustomer
    }
}
