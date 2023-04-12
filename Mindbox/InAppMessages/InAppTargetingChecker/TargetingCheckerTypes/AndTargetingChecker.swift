//
//  AndTargetingChecker.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 19.01.2023.
//

import Foundation

final class AndTargetingChecker: InternalTargetingChecker<AndTargeting> {
    weak var checker: InAppTargetingCheckerProtocol?
    
    override func prepareInternal(targeting: AndTargeting, context: inout PreparationContext) -> Void {
        for node in targeting.nodes {
            guard let checker = checker,
                    let target = checker.checkerMap[node] else {
                return
            }

            target(node).prepare(&context)
        }
    }
    
    override func checkInternal(targeting: AndTargeting) -> Bool {
        guard let checker = checker else {
            return false
        }

        for node in targeting.nodes {
            if node == .unknown {
                return false
            }
            
            guard let target = checker.checkerMap[node] else {
                return false
            }
            
            if target(node).check() == false {
                return false
            }
        }
        
        return true
    }
}
