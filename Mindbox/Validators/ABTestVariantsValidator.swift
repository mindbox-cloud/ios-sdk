//
//  ABTestVariantsValidator.swift
//  Mindbox
//
//  Created by vailence on 15.06.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

class ABTestVariantsValidator: Validator {
    typealias T = ABTest.ABTestVariant?

    private let typeInApps = "inapps"
    private let all = "all"
    private let concrete = "concrete"

    func isValid(item: ABTest.ABTestVariant?) -> Bool {
        guard let item = item else {
            Logger.common(message: "Variant item can not be null.")
            return false
        }

        guard !item.id.isEmpty else {
            Logger.common(message: "The 'id' field can not be null or empty.")
            return false
        }

        guard let modulus = item.modulus else {
            Logger.common(message: "The 'modulus' field can not be null.")
            return false
        }

        guard let upper = modulus.upper else {
            Logger.common(message: "The 'upper' field in 'modulus' can not be null.")
            return false
        }

        guard modulus.lower >= 0,
              upper <= 100,
              modulus.lower < upper else {
            Logger.common(message: "The 'lower' and 'upper' fields are invalid.")
            return false
        }

        guard let objects = item.objects else {
            Logger.common(message: "The 'objects' field can not be null.")
            return false
        }

        guard objects.count == 1 else {
            Logger.common(message: "The 'objects' field must contain only one item.")
            return false
        }

        guard objects.first?.type.rawValue == typeInApps else {
            Logger.common(message: "The 'objects' field type can be \(typeInApps).")
            return false
        }

        guard let kind = objects.first?.kind.rawValue,
              kind == all || kind == concrete else {
            Logger.common(message: "The 'kind' field must be \(all) or \(concrete).")
            return false
        }

        return true
    }
}
