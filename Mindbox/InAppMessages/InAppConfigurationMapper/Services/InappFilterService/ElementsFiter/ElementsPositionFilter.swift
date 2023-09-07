//
//  ElementsPositionFilter.swift
//  Mindbox
//
//  Created by vailence on 07.09.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

protocol ElementsPositionFilterProtocol {
    func filter(_ position: ContentElementPositionDTO?) throws -> ContentElementPosition?
}

final class ElementsPositionFilterService: ElementsPositionFilterProtocol {
    
    enum Constants {
        static let defaultMargin = ContentElementPositionMargin(kind: .proportion, top: 0.02, right: 0.02, left: 0.02, bottom: 0.02)
        
    }
    
    func filter(_ position: ContentElementPositionDTO?) throws -> ContentElementPosition? {
        guard let position = position,
              let margin = position.margin else {
            return ContentElementPosition(margin: Constants.defaultMargin)
        }
        
        let marginRange: ClosedRange<Double> = 0...1
        
        switch margin.kind {
            case .proportion:
                if let top = margin.top,
                   let left = margin.left,
                   let right = margin.right,
                   let bottom = margin.bottom,
                   marginRange.contains(top),
                   marginRange.contains(left),
                   marginRange.contains(right),
                   marginRange.contains(bottom) {
                    let customMargin = ContentElementPositionMargin(kind: margin.kind,
                                                                    top: top,
                                                                    right: right,
                                                                    left: left,
                                                                    bottom: bottom)
                    return ContentElementPosition(margin: customMargin)
                }
            case .unknown:
                return ContentElementPosition(margin: Constants.defaultMargin)
        }
        
        return nil
    }
}
