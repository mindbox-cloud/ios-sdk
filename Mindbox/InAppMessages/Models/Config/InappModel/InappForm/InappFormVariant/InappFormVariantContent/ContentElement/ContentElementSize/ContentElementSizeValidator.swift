//
//  ContentElementSizeValidator.swift
//  Mindbox
//
//  Created by vailence on 11.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

class ContentElementSizeValidator: Validator {
    typealias T = ContentElementSize

    func isValid(item: ContentElementSize) -> Bool {
        guard item.width > 0 else {
            Logger.common(message: "Content element size width is negative. Width: [\(item.width)", level: .error, category: .inAppMessages)
            return false

        }
        guard item.height > 0 else {
            Logger.common(message: "Content element size height is negative. Height: [\(item.height)", level: .error, category: .inAppMessages)
            return false
        }
        
        return true
    }
}
