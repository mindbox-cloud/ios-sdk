//
//  InternalTargetingChecker.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 17.01.2023.
//  Copyright © 2023 Mikhail Barilov. All rights reserved.
//

import Foundation

struct PreparationContext {
    var segments: [String] = []
    var isNeedGeoRequest: Bool = false
    var productSegments: [String] = []
    var operationInapps: [String: Set<String>] = [:]
}

protocol ITargetingChecker: AnyObject {
    func prepare(id: String, targeting: ITargeting, context: inout PreparationContext)
    func check(targeting: ITargeting) -> Bool
}

class InternalTargetingChecker<T: ITargeting>: ITargetingChecker {
    func prepare(id: String, targeting: ITargeting, context: inout PreparationContext) {
        guard let specificTargeting = targeting as? T else {
            fatalError("Failed to cast targeting to type \(T.self)")
        }
        prepareInternal(id: id, targeting: specificTargeting, context: &context)
    }

    func prepareInternal(id: String, targeting: T, context: inout PreparationContext) {
        return
    }

    func check(targeting: ITargeting) -> Bool {
        guard let specificTargeting = targeting as? T else {
            fatalError("Failed to cast targeting to type \(T.self)")
        }

        return checkInternal(targeting: specificTargeting)
    }

    func checkInternal(targeting: T) -> Bool {
        assertionFailure("This method must be overridden")
        return false
    }
}
