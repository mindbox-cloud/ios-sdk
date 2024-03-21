//
//  VisitTargetingChecker.swift
//  Mindbox
//
//  Created by vailence on 21.03.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation

final class VisitTargetingChecker: InternalTargetingChecker<VisitTargeting> {
    weak var checker: TargetingCheckerContextProtocol?
    
    override func prepareInternal(targeting: VisitTargeting, context: inout PreparationContext) -> Void {
        
    }
    
    override func checkInternal(targeting: VisitTargeting) -> Bool {
        guard let checker = checker else {
            return false
        }
        
        switch SessionTemporaryStorage.shared.pushPermissionStatus {
            case .notDetermined, .denied:
                return true
            case .authorized, .provisional, .ephemeral:
                return false
            @unknown default:
                return false
        }
    }
}
