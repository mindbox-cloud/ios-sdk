//
//  InternalTargetingChecker.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 17.01.2023.
//

import Foundation

protocol InAppTargetingCheckerVariablesProtocol {
    var context: PreparationContext { get set }
    var checkedSegmentations: [SegmentationCheckResponse.CustomerSegmentation] { get set }
}

protocol InAppTargetingCheckerFunctionsProtocol {
    func prepare(targeting: Targeting)
    func check(targeting: Targeting) -> Bool
}

protocol InAppTargetingCheckerProtocol: InAppTargetingCheckerVariablesProtocol, InAppTargetingCheckerFunctionsProtocol {
}

final class InAppTargetingChecker: InAppTargetingCheckerProtocol {
    var context = PreparationContext()
    var checkedSegmentations: [SegmentationCheckResponse.CustomerSegmentation] = []
}

extension InAppTargetingChecker {
    func prepare(targeting: Targeting) {
        checkerMap[targeting]!(targeting).prepare(&context)
    }
    
    func check(targeting: Targeting) -> Bool {
        return checkerMap[targeting]!(targeting).check()
    }
}
