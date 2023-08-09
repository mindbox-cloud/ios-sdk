//
//  InappFormVariantValidator.swift
//  Mindbox
//
//  Created by vailence on 03.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

class InappFormVariantValidator: Validator {
    typealias T = InappFormVariant
    
    func isValid(item: InappFormVariant) -> Bool {
        if item.type == .unknown {
            return false
        }
        
        if item.content == nil && item.type == .modal {
            return false
        }
        
        return true
    }
}
