//
//  ElementsColorFilterService.swift
//  Mindbox
//
//  Created by vailence on 15.09.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

protocol ElementsColorFilterProtocol {
    func filter(_ color: String?) throws -> String
}

final class ElementsColorFilterService: ElementsColorFilterProtocol {
    enum Constants {
        static let defaultColor = "#FFFFFF"
    }
    
    func filter(_ color: String?) throws -> String {
        guard let color = color, color.isHexValid() else {
            Logger.common(message: "Color is invalid or missing. Default value set: [\(Constants.defaultColor)]", level: .debug, category: .inAppMessages)
            return Constants.defaultColor
        }
        
        return color
    }
}
