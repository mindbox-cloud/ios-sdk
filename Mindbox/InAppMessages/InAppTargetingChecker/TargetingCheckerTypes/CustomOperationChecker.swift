//
//  CustomOperationChecker.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 10.03.2023.
//  Copyright © 2023 Mikhail Barilov. All rights reserved.
//

import Foundation

final class CustomOperationChecker: InternalTargetingChecker<CustomOperationTargeting> {
    weak var checker: TargetingCheckerContextProtocol?
    
    override func prepareInternal(targeting: CustomOperationTargeting, context: inout PreparationContext) {
        context.operationsName.append(targeting.systemName)
    }
    
    override func checkInternal(targeting: CustomOperationTargeting) -> Bool {
        guard let checker = checker,
              let operationName = checker.operationName,
              !targeting.systemName.isEmpty else {
            return false
        }
        
        return operationName == targeting.systemName
    }
}
