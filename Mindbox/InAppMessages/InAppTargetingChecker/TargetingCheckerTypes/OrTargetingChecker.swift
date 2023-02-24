//
//  OrTargetingChecker.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 19.01.2023.
//

import Foundation

final class OrTargetingChecker: InternalTargetingChecker<OrTargeting> {
    weak var checker: InAppTargetingCheckerProtocol?
    
    override func prepareInternal(targeting: OrTargeting, context: inout PreparationContext) -> Void {
        for node in targeting.nodes {
            guard let checker = checker,
                    let target = checker.checkerMap[node] else {
                return
            }
            
            target(node).prepare(&context)
        }
    }
    
    override func checkInternal(targeting: OrTargeting) -> Bool {
        guard let checker = checker else {
            return false
        }
        
        for node in targeting.nodes {
            if case .segment = node {
                if checker.checkedSegmentations == nil {
                    return false
                }
            } else if case .city = node {
                if checker.geoModels == nil {
                    return false
                }
            } else if case .region = node {
                if checker.geoModels == nil {
                    return false
                }
            } else if case .country = node {
                if checker.geoModels == nil {
                    return false
                }
            }
        }
        
        for node in targeting.nodes {
            if node == .unknown {
                return false
            }
            
            guard let target = checker.checkerMap[node] else {
                return false
            }
            if target(node).check() == true {
                return true
            }
        }
        
        return false
    }
}
