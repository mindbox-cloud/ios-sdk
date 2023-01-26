//
//  TrueTargetingChecker.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 19.01.2023.
//

import Foundation

final class TrueTargetingChecker: InternalTargetingChecker<TrueTargeting> {
    override func checkInternal(targeting: TrueTargeting) -> Bool {
        return true
    }
}
