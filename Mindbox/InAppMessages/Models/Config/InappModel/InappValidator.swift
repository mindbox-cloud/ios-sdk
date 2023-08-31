//
//  InappValidator.swift
//  Mindbox
//
//  Created by vailence on 03.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

class InappValidator: Validator {
    typealias T = InApp

    private let sdkVersionValidator: SDKVersionValidator

    init() {
        self.sdkVersionValidator = SDKVersionValidator(sdkVersionNumeric: Constants.Versions.sdkVersionNumeric)
    }

    func isValid(item: InApp) -> Bool {
        if item.id.isEmpty {
            Logger.common(message: "In-app id cannot be empty. In-app will be ignored.", level: .error, category: .inAppMessages)
            return false
        }
        
        if !sdkVersionValidator.isValid(item: item.sdkVersion) {
            Logger.common(message: "Invalid SDK version for In-app. In-app with id \(item.id) will be ignored.", level: .error, category: .inAppMessages)
            return false
        }
        
        return true
    }
}
