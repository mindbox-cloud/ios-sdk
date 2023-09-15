//
//  ElementsFilter.swift
//  Mindbox
//
//  Created by vailence on 07.09.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

protocol ElementsFilterProtocol {
    func filter(_ elements: [ContentElementDTO]?) throws -> [ContentElement]
}

final class ElementsFilterService: ElementsFilterProtocol {
    
    enum Constants {
        static let defaultColor = "#000000"
        static let lineWidth = 1
    }
    
    private let sizeFilter: ElementsSizeFilterProtocol
    private let positionFilter: ElementsPositionFilterProtocol
    private let colorFilter: ElementsColorFilterProtocol
    
    init(sizeFilter: ElementsSizeFilterProtocol, positionFilter: ElementsPositionFilterProtocol, colorFilter: ElementsColorFilterProtocol) {
        self.sizeFilter = sizeFilter
        self.positionFilter = positionFilter
        self.colorFilter = colorFilter
    }
    
    func filter(_ elements: [ContentElementDTO]?) throws -> [ContentElement] {
        guard let elements = elements, !elements.isEmpty else {
            return []
        }
        
        var filteredElements: [ContentElement] = []
        
        elementsLoop: for element in elements {
            if element.elementType == .unknown {
                continue
            }
            
            switch element {
                case .closeButton(let closeButtonElementDTO):
                    let size = try sizeFilter.filter(closeButtonElementDTO.size)
                    let position = try positionFilter.filter(closeButtonElementDTO.position)
                    let color = try colorFilter.filter(closeButtonElementDTO.color?.element)
                    let customCloseButtonElement = CloseButtonElement(color: color,
                                                                      lineWidth: closeButtonElementDTO.lineWidth?.element ?? Constants.lineWidth,
                                                                      size: size,
                                                                      position: position)
                    let element = try ContentElement(type: .closeButton, closeButton: customCloseButtonElement)
                    filteredElements.append(element)
                case .unknown:
                    continue elementsLoop
            }
        }

        return filteredElements
    }
}
