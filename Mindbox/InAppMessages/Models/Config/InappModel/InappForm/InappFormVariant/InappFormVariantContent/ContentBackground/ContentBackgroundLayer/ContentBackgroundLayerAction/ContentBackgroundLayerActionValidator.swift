//
//  ContentBackgroundLayerActionValidator.swift
//  Mindbox
//
//  Created by vailence on 03.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

class ContentBackgroundLayerActionValidator: Validator {
    typealias T = ContentBackgroundLayerAction
    
    func isValid(item: ContentBackgroundLayerAction) -> Bool {
        if item.type == .unknown {
            return false
        }

        if item.type == .redirectUrl && (item.intentPayload == nil || item.value == nil) {
            return false
        }
        
        return true
    }
}
