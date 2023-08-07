//
//  InappValidator.swift
//  Mindbox
//
//  Created by vailence on 03.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

class InappValidator: Validator {
    typealias T = InApp

    private let sdkVersionValidator: SDKVersionValidator

    init() {
        self.sdkVersionValidator = SDKVersionValidator(sdkVersionNumeric: Constants.Versions.sdkVersionNumeric)
    }

    func isValid(item: InApp) -> Bool {
        if item.id.isEmpty {
            return false
        }
        
        if !sdkVersionValidator.isValid(item: item.sdkVersion) {
            return false
        }
        
        return true
    }
}
