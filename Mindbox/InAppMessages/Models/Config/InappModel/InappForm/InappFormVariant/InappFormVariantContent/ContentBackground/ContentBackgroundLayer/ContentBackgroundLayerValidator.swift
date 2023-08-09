//
//  ContentBackgroundLayerValidator.swift
//  Mindbox
//
//  Created by vailence on 03.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

class ContentBackgroundLayerValidator: Validator {
    typealias T = ContentBackgroundLayer
    
    func isValid(item: ContentBackgroundLayer) -> Bool {
        if item.type == .unknown {
            return false
        }
        
        if item.action == nil && item.type == .image {
            return false
        }
        
        if item.source == nil && item.type == .image {
            return false
        }
        
        return true
    }
}
