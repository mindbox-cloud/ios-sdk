//
//  ABTestValidator.swift
//  Mindbox
//
//  Created by vailence on 15.06.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

class ABTestValidator: Validator {
    
    typealias T = ABTest?
    
    private let sdkVersionValidator: SDKVersionValidator
    private lazy var variantsValidator = ABTestVariantsValidator()
    
    init(sdkVersionValidator: SDKVersionValidator) {
        self.sdkVersionValidator = sdkVersionValidator
    }

    func isValid(item: ABTest?) -> Bool {
        guard let item = item else {
            Logger.common(message: "The element in abtests block cannot be null. All abtests will not be used.")
            return false
        }
        
        if item.id.isEmpty {
            Logger.common(message: "The field 'id' in abtests block cannot be null. All abtests will not be used.")
            return false
        }

        if item.sdkVersion == nil || !sdkVersionValidator.isValid(item: item.sdkVersion) {
            Logger.common(message: "In abtest \(item.id) 'sdkVersion' field is invalid. All abtests will not be used.")
            return false
        }

        if item.salt?.isEmpty ?? true {
            Logger.common(message: "In abtest \(item.id) 'salt' field is invalid. All abtests will not be used.")
            return false
        }

        guard let variants = item.variants, variants.count >= 2 else {
            Logger.common(message: "In abtest \(item.id) 'variants' field must have at least two items. All abtests will not be used.")
            return false
        }

        if variants.contains(where: { !variantsValidator.isValid(item: $0) }) {
            Logger.common(message: "In abtest \(item.id) 'variants' field is invalid. All abtests will not be used.")
            return false
        }

        var start = 0
        let sortedVariants = variants.sorted {
            ($0.modulus?.lower ?? 0) < ($1.modulus?.lower ?? 0)
        }
        
        for variant in sortedVariants {
            guard let modulus = variant.modulus else {
                Logger.common(message: "In abtest \(item.id) 'variants' field contains a variant with a nil modulus. All abtests will not be used.")
                return false
            }
            
            if modulus.lower == start {
                start = modulus.upper
            } else {
                Logger.common(message: "In abtest \(item.id) 'variants' field does not have full cover. All abtests will not be used.")
                return false
            }
        }
        
        if !(99...100).contains(start) {
            Logger.common(message: "In abtest \(item.id) 'variants' field does not have full cover. All abtests will not be used.")
            return false
        }
        
        return true
    }
}
