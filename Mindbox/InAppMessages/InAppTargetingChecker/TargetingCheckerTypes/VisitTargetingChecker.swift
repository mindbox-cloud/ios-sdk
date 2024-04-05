//
//  VisitTargetingChecker.swift
//  Mindbox
//
//  Created by vailence on 21.03.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

final class VisitTargetingChecker: InternalTargetingChecker<VisitTargeting> {
    
    weak var checker: TargetingCheckerPersistenceStorageProtocol?
    
    override func checkInternal(targeting: VisitTargeting) -> Bool {
        guard let checker = checker else {
            return false
        }
        
        guard let count = checker.persistenceStorage.userVisitCount else {
            Logger.common(message: "VisitTargetingChecker. userVisitCount doesn't exists.", level: .error, category: .inAppMessages)
            return false
        }
        
        switch targeting.kind {
            case .gte:
                return count >= targeting.value
            case .lte:
                return count <= targeting.value
            case .equals:
                return count == targeting.value
            case .notEquals:
                return count != targeting.value
        }
    }
}
