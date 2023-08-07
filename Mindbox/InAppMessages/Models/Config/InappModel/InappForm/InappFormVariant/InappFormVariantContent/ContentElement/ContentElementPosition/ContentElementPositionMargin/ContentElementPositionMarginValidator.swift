//
//  ContentElementPositionMarginValidator.swift
//  Mindbox
//
//  Created by vailence on 04.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

class ContentElementPositionMarginValidator: Validator {
    typealias T = ContentElementPositionMargin
    
    func isValid(item: ContentElementPositionMargin) -> Bool {
        if item.kind == .unknown {
            return false
        }
        
        return true
    }
}
