//
//  ProductIDChecker.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 29.03.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

final class ProductIDChecker: InternalTargetingChecker<ProductIDTargeting> {
    weak var checker: TargetingCheckerContextProtocol?

    override func prepareInternal(targeting: ProductIDTargeting, context: inout PreparationContext) {

    }

    override func checkInternal(targeting: ProductIDTargeting) -> Bool {
        guard let checker = checker,
              let event = checker.event,
              let ids = event.model?.viewProduct?.product.ids,
              !ids.isEmpty else {
            return false
        }

        for i in ids {
            switch targeting.kind {
            case .substring:
                if i.value.contains(targeting.name) { return true }
            case .notSubstring:
                if !i.value.contains(targeting.name) { return true }
            case .startsWith:
                if i.value.hasPrefix(targeting.name) { return true }
            case .endsWith:
                if i.value.hasSuffix(targeting.name) { return true }
            }
        }

        return false
    }
}
