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
    var operationsName: [String] = []
}

protocol ITargetingChecker: AnyObject {
    func prepare(targeting: ITargeting, context: inout PreparationContext) -> Void
    func check(targeting: ITargeting) -> Bool
}

class InternalTargetingChecker<T: ITargeting>: ITargetingChecker {
    func prepare(targeting: ITargeting, context: inout PreparationContext) {
        prepareInternal(targeting: targeting as! T, context: &context)
    }
    
    func prepareInternal(targeting: T, context: inout PreparationContext) -> Void {
        return
    }
    
    func check(targeting: ITargeting) -> Bool {
        return checkInternal(targeting: targeting as! T)
    }
    
    func checkInternal(targeting: T) -> Bool {
        assertionFailure("This method must be overridden")
        return false
    }
}
