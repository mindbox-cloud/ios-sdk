//
//  ElementsColorFilterService.swift
//  Mindbox
//
//  Created by vailence on 15.09.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

protocol ElementsColorFilterProtocol {
    func filter(_ color: String?) throws -> String
}

final class ElementsColorFilterService: ElementsColorFilterProtocol {
    enum Constants {
        static let defaultColor = "#000000"
    }
    
    func filter(_ color: String?) throws -> String {
        guard let color = color else {
            return Constants.defaultColor
        }
        return color.isHexValid() ? color : Constants.defaultColor
    }
}
