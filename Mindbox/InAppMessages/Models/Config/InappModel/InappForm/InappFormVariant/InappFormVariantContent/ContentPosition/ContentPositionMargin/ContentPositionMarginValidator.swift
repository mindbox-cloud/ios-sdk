//
//  ContentPositionMarginValidator.swift
//  Mindbox
//
//  Created by vailence on 14.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

class ContentPositionMarginValidator: Validator {
    
    typealias T = ContentPositionMargin
    
    func isValid(item: ContentPositionMargin) -> Bool {
        if item.kind == .unknown {
            return false
        }
        
        return true
    }
}
