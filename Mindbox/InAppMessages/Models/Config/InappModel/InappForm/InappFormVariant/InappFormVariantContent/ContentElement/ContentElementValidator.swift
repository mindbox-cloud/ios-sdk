//
//  ContentElementValidator.swift
//  Mindbox
//
//  Created by vailence on 04.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

class ContentElementValidator: Validator {
    typealias T = ContentElement
    
    func isValid(item: ContentElement) -> Bool {
        if item.type == .unknown {
            return false
        }
    
        return true
    }
}
