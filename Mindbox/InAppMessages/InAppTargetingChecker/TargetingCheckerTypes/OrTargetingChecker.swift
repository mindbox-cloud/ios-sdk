//
//  OrTargetingChecker.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 19.01.2023.
//

import Foundation

final class OrTargetingChecker: InternalTargetingChecker<OrTargeting> {
    weak var checker: TargetingCheckerMap?
    
    override func prepareInternal(targeting: OrTargeting, context: inout PreparationContext) -> Void {
        for node in targeting.nodes {
            guard let checker = checker else {
                assertionFailure("Need to init checker")
                return
            }
            
            guard let target = checker.checkerMap[node] else {
                assertionFailure("CheckerMap does not contain node: \(node)")
                return
            }
            target(node).prepare(&context)
        }
    }
    
    override func checkInternal(targeting: OrTargeting) -> Bool {
        guard let checker = checker else {
            assertionFailure("Need to init checker")
            return false
        }
        for node in targeting.nodes {
            guard let target = checker.checkerMap[node] else {
                assertionFailure("CheckerMap does not contain node: \(node)")
                return false
            }
            if target(node).check() == true {
                return true
            }
        }
        
        return false
    }
}
