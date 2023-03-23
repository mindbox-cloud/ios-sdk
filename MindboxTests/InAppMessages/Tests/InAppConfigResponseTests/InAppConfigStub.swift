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
    func getCategoryID_Substring() -> InAppConfigResponse {
        let categoryIdTargeting = CategoryIDTargeting(kind: .substring, value: "auto")
        let targeting = Targeting.viewProductCategoryId(categoryIdTargeting)
        let settings = InAppConfigResponse.Settings(operations: .init(viewProduct: nil,
                                                                      viewCategory: .init(systemName: "Hello"),
                                                                      setCart: nil))
        return .init(inapps: getInapps(with: targeting), monitoring: nil, settings: settings)
    }
    
    func getCategoryID_notSubstring() -> InAppConfigResponse {
        let categoryIdTargeting = CategoryIDTargeting(kind: .notSubstring, value: "auto")
        let targeting = Targeting.viewProductCategoryId(categoryIdTargeting)
        let settings = InAppConfigResponse.Settings(operations: .init(viewProduct: nil,
                                                                      viewCategory: .init(systemName: "Hello"),
                                                                      setCart: nil))
        return .init(inapps: getInapps(with: targeting), monitoring: nil, settings: settings)
    }
    
    func getCategoryID_startWith() -> InAppConfigResponse {
        let categoryIdTargeting = CategoryIDTargeting(kind: .startsWith, value: "auto")
        let targeting = Targeting.viewProductCategoryId(categoryIdTargeting)
        let settings = InAppConfigResponse.Settings(operations: .init(viewProduct: nil,
                                                                      viewCategory: .init(systemName: "Hello"),
                                                                      setCart: nil))
        return .init(inapps: getInapps(with: targeting), monitoring: nil, settings: settings)
    }
    
    func getCategoryID_endWith() -> InAppConfigResponse {
        let categoryIdTargeting = CategoryIDTargeting(kind: .endsWith, value: "auto")
        let targeting = Targeting.viewProductCategoryId(categoryIdTargeting)
        let settings = InAppConfigResponse.Settings(operations: .init(viewProduct: nil,
                                                                      viewCategory: .init(systemName: "Hello"),
                                                                      setCart: nil))
        return .init(inapps: getInapps(with: targeting), monitoring: nil, settings: settings)
    }
    
    func getCategoryIDIn_Any() -> InAppConfigResponse {
        let categoryIdInTargeting = CategoryIDInTargeting(kind: .any,
                                                          values: [.init(id: "1", name: "Test")])
        let targeting = Targeting.viewProductCategoryIdIn(categoryIdInTargeting)
        let settings = InAppConfigResponse.Settings(operations: .init(viewProduct: nil,
                                                                      viewCategory: .init(systemName: "Hello"),
                                                                      setCart: nil))
        return .init(inapps: getInapps(with: targeting), monitoring: nil, settings: settings)
    }
    
    func getCategoryIDIn_None() -> InAppConfigResponse {
        let categoryIdInTargeting = CategoryIDInTargeting(kind: .none,
                                                          values: [.init(id: "1", name: "Test")])
        let targeting = Targeting.viewProductCategoryIdIn(categoryIdInTargeting)
        let settings = InAppConfigResponse.Settings(operations: .init(viewProduct: nil,
                                                                      viewCategory: .init(systemName: "Hello"),
                                                                      setCart: nil))
        return .init(inapps: getInapps(with: targeting), monitoring: nil, settings: settings)
    }
    
    func getInapps(with targeting: Targeting) -> [InAppConfigResponse.InApp] {
        return  [.init(id: "0",
                       sdkVersion: .init(min: 5, max: nil),
                       targeting: targeting,
                       form: getForm())]
    }
    
    func getForm() -> InAppConfigResponse.InAppFormVariants {
        .init(variants: [.init(imageUrl: "1", redirectUrl: "2", intentPayload: "3", type: "simpleImage")])
    }
}
