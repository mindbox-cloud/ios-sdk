//
//  ContentBackgroundLayerSourceValidator.swift
//  Mindbox
//
//  Created by vailence on 03.08.2023.
//

import Foundation

class ContentBackgroundLayerSourceValidator: Validator {
    typealias T = ContentBackgroundLayerSource
    
    func isValid(item: ContentBackgroundLayerSource) -> Bool {
        if item.type == .unknown {
            return false
        }

        if item.type == .url && item.value == nil {
            return false
        }
        
        return true
    }
}
