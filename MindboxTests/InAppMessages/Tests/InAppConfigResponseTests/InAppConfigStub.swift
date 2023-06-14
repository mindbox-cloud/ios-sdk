//
//  InAppConfigStub.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 21.03.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation
@testable import Mindbox

final class InAppConfigStub {
    func getCategoryID_Substring() -> ConfigResponse {
        let categoryIdTargeting = CategoryIDTargeting(kind: .substring, value: "oot")
        let targeting = Targeting.viewProductCategoryId(categoryIdTargeting)
        let settings = Settings(operations: .init(viewProduct: nil,
                                                                      viewCategory: .init(systemName: "Hello"),
                                                                      setCart: nil))
        return .init(inapps: getInapps(with: targeting), monitoring: nil, settings: settings)
    }
    
    func getCategoryID_notSubstring() -> ConfigResponse {
        let categoryIdTargeting = CategoryIDTargeting(kind: .notSubstring, value: "oot")
        let targeting = Targeting.viewProductCategoryId(categoryIdTargeting)
        let settings = Settings(operations: .init(viewProduct: nil,
                                                                      viewCategory: .init(systemName: "Hello"),
                                                                      setCart: nil))
        return .init(inapps: getInapps(with: targeting), monitoring: nil, settings: settings)
    }
    
    func getCategoryID_startWith() -> ConfigResponse {
        let categoryIdTargeting = CategoryIDTargeting(kind: .startsWith, value: "oot")
        let targeting = Targeting.viewProductCategoryId(categoryIdTargeting)
        let settings = Settings(operations: .init(viewProduct: nil,
                                                                      viewCategory: .init(systemName: "Hello"),
                                                                      setCart: nil))
        return .init(inapps: getInapps(with: targeting), monitoring: nil, settings: settings)
    }
    
    func getCategoryID_endWith() -> ConfigResponse {
        let categoryIdTargeting = CategoryIDTargeting(kind: .endsWith, value: "ots")
        let targeting = Targeting.viewProductCategoryId(categoryIdTargeting)
        let settings = Settings(operations: .init(viewProduct: nil,
                                                                      viewCategory: .init(systemName: "Hello"),
                                                                      setCart: nil))
        return .init(inapps: getInapps(with: targeting), monitoring: nil, settings: settings)
    }
    
    func getCategoryIDIn_Any() -> ConfigResponse {
        let categoryIdInTargeting = CategoryIDInTargeting(kind: .any,
                                                          values: [.init(id: "testik2", name: "System1C"),
                                                                   .init(id: "81", name: "TestSite")])
        let targeting = Targeting.viewProductCategoryIdIn(categoryIdInTargeting)
        let settings = Settings(operations: .init(viewProduct: nil,
                                                                      viewCategory: .init(systemName: "Hello"),
                                                                      setCart: nil))
        return .init(inapps: getInapps(with: targeting), monitoring: nil, settings: settings)
    }
    
    func getCategoryIDIn_None() -> ConfigResponse {
        let categoryIdInTargeting = CategoryIDInTargeting(kind: .none,
                                                          values: [.init(id: "testik2", name: "System1C"),
                                                                   .init(id: "81", name: "TestSite")])
        let targeting = Targeting.viewProductCategoryIdIn(categoryIdInTargeting)
        let settings = Settings(operations: .init(viewProduct: nil,
                                                                      viewCategory: .init(systemName: "Hello"),
                                                                      setCart: nil))
        return .init(inapps: getInapps(with: targeting), monitoring: nil, settings: settings)
    }
    
    func getInapps(with targeting: Targeting) -> [InApp] {
        return  [.init(id: "0",
                       sdkVersion: .init(min: 5, max: nil),
                       targeting: targeting,
                       form: getForm())]
    }
    
    func getForm() -> InApp.InAppFormVariants {
        .init(variants: [.init(imageUrl: "1", redirectUrl: "2", intentPayload: "3", type: "simpleImage")])
    }
    func getProductID_Substring() -> ConfigResponse {
        let productIdTargeting = ProductIDTargeting(kind: .substring, value: "oot")
        let targeting = Targeting.viewProductId(productIdTargeting)
        let settings = Settings(operations: .init(viewProduct: nil,
                                                                      viewCategory: .init(systemName: "Hello"),
                                                                      setCart: nil))
        return .init(inapps: getInapps(with: targeting), monitoring: nil, settings: settings)
    }

    func getProductID_notSubstring() -> ConfigResponse {
        let productIdTargeting = ProductIDTargeting(kind: .notSubstring, value: "oot")
        let targeting = Targeting.viewProductId(productIdTargeting)
        let settings = Settings(operations: .init(viewProduct: nil,
                                                                      viewCategory: .init(systemName: "Hello"),
                                                                      setCart: nil))
        return .init(inapps: getInapps(with: targeting), monitoring: nil, settings: settings)
    }

    func getProductID_startsWith() -> ConfigResponse {
        let productIdTargeting = ProductIDTargeting(kind: .startsWith, value: "oot")
        let targeting = Targeting.viewProductId(productIdTargeting)
        let settings = Settings(operations: .init(viewProduct: nil,
                                                                      viewCategory: .init(systemName: "Hello"),
                                                                      setCart: nil))
        return .init(inapps: getInapps(with: targeting), monitoring: nil, settings: settings)
    }

    func getProductID_endsWith() -> ConfigResponse {
        let productIdTargeting = ProductIDTargeting(kind: .endsWith, value: "ots")
        let targeting = Targeting.viewProductId(productIdTargeting)
        let settings = Settings(operations: .init(viewProduct: nil,
                                                                      viewCategory: .init(systemName: "Hello"),
                                                                      setCart: nil))
        return .init(inapps: getInapps(with: targeting), monitoring: nil, settings: settings)
    }

    func getProductSegment_Any() -> ConfigResponse {
        let productSegmentTargeting = ProductSegmentTargeting(kind: .positive, segmentationInternalId: "1", segmentationExternalId: "2", segmentExternalId: "3")
        let targeting = Targeting.viewProductSegment(productSegmentTargeting)
        let settings = Settings(operations: .init(viewProduct: .init(systemName: "Hello"),
                                                                      viewCategory: nil,
                                                                      setCart: nil))
        return .init(inapps: getInapps(with: targeting), monitoring: nil, settings: settings)
    }

    func getProductSegment_None() -> ConfigResponse {
        let productSegmentTargeting = ProductSegmentTargeting(kind: .negative, segmentationInternalId: "1", segmentationExternalId: "2", segmentExternalId: "3")
        let targeting = Targeting.viewProductSegment(productSegmentTargeting)
        let settings = Settings(operations: .init(viewProduct: .init(systemName: "Hello"),
                                                                      viewCategory: nil,
                                                                      setCart: nil))
        return .init(inapps: getInapps(with: targeting), monitoring: nil, settings: settings)
    }
}
