//
//  ContentPositionFilter.swift
//  Mindbox
//
//  Created by vailence on 07.09.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

protocol ContentPositionFilterProtocol {
    func filter(_ contentPosition: ContentPositionDTO?) throws -> ContentPosition
}

final class ContentPositionFilterService: ContentPositionFilterProtocol {
    
    enum Constants {
        static let defaultGravity = ContentPositionGravity(vertical: .bottom, horizontal: .center)
        static let defaultMargin = ContentPositionMargin(kind: .dp, top: 0, right: 0, left: 0, bottom: 0)
        static let defaultContentPosition = ContentPosition(gravity: defaultGravity, margin: defaultMargin)
    }
    
    func filter(_ contentPosition: ContentPositionDTO?) throws -> ContentPosition {
        guard let contentPosition = contentPosition else {
            Logger.common(message: "Content position is invalid or missing. Default value set: [\(Constants.defaultContentPosition)].", level: .debug, category: .inAppMessages)
            return Constants.defaultContentPosition
        }
        
        var customGravity: ContentPositionGravity
        if let gravity = contentPosition.gravity {
            let vertical = gravity.vertical ?? .bottom
            let horizontal = gravity.horizontal ?? .center
            customGravity = ContentPositionGravity(vertical: vertical, horizontal: horizontal)
        } else {
            Logger.common(message: "Gravity is invalid or missing. Default value set: [\(Constants.defaultGravity)].", level: .debug, category: .inAppMessages)
            customGravity = Constants.defaultGravity
        }
        
        var customMargin: ContentPositionMargin?
        if let margin = contentPosition.margin {
            switch margin.kind {
                case .dp:
                    if let top = margin.top,
                       let left = margin.left,
                       let right = margin.right,
                       let bottom = margin.bottom,
                       top >= 0,
                       left >= 0,
                       right >= 0,
                       bottom >= 0 {
                        customMargin = ContentPositionMargin(kind: margin.kind, top: top, right: right, left: left, bottom: bottom)
                    }
                case .unknown:
                    Logger.common(message: "Content position margin kind is unknown. Default value set: [\(Constants.defaultMargin)].", level: .debug, category: .inAppMessages)
                    customMargin = Constants.defaultMargin
            }
        } else {
            Logger.common(message: "Content position margin is invalid or missing. Default value set: [\(Constants.defaultMargin)].", level: .debug, category: .inAppMessages)
            customMargin = Constants.defaultMargin
        }
        
        guard let customMargin = customMargin else {
            throw CustomDecodingError.unknownType("ContentPositionFilterService validation not passed. Inapp will be skipped.")
        }
        
        return ContentPosition(gravity: customGravity, margin: customMargin)
    }
}
