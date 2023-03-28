//
//  CategoryIDInChecker.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 21.03.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

final class CategoryIDInChecker: InternalTargetingChecker<CategoryIDInTargeting> {
    weak var checker: TargetingCheckerContextProtocol?
    
    override func prepareInternal(targeting: CategoryIDInTargeting, context: inout PreparationContext) {
        
    }
    
    override func checkInternal(targeting: CategoryIDInTargeting) -> Bool {
        guard let checker = checker,
              let event = checker.event,
              let ids = event.model?.viewProductCategory.productCategory.ids,
              !ids.isEmpty else {
            return false
        }
        
        for i in targeting.values {
            if ids.contains(where: { $0.key.lowercased() == i.name.lowercased() && $0.value.lowercased() == i.id.lowercased() }) {
                switch targeting.kind {
                case .any:
                    return true
                case .none:
                    return false
                }
            }
        }
        
        return targeting.kind == .any ? false : true
    }
}
