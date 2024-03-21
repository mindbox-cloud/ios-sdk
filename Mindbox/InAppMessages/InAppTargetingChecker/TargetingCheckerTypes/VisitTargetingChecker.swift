//
//  VisitTargetingChecker.swift
//  Mindbox
//
//  Created by vailence on 21.03.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation

final class VisitTargetingChecker: InternalTargetingChecker<VisitTargeting> {
    override func checkInternal(targeting: VisitTargeting) -> Bool {
        // MARK: - Change logic when [iOS] Подсчет количества посещений приложения will be done
        switch targeting.kind {
            case .gte:
                return targeting.value >= 1
            case .lte:
                return targeting.value <= 1
            case .equals:
                return targeting.value == 1
            case .notEquals:
                return targeting.value != 1
        }
    }
}
