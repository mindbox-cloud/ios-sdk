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

    override func prepareInternal(id: String, targeting: ProductIDTargeting, context: inout PreparationContext) {
        if let key = SessionTemporaryStorage.shared.viewProductOperation {
            context.operationInapps[key.lowercased(), default: []].insert(id)
        }
    }

    override func checkInternal(targeting: ProductIDTargeting) -> Bool {
        guard let checker = checker,
              let event = checker.event,
              let ids = event.model?.viewProduct?.product.ids,
              !ids.isEmpty else {
            return false
        }

        for i in ids {
            let lowercaseValue = i.value.lowercased()
            let lowercaseName = targeting.name.lowercased()
            switch targeting.kind {
            case .substring:
                if lowercaseValue.contains(lowercaseName) { return true }
            case .notSubstring:
                if !lowercaseValue.contains(lowercaseName) { return true }
            case .startsWith:
                if lowercaseValue.hasPrefix(lowercaseName) { return true }
            case .endsWith:
                if lowercaseValue.hasSuffix(lowercaseName) { return true }
            }
        }

        return false
    }
}
