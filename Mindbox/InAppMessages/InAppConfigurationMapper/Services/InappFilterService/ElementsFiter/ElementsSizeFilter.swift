//
//  ElementsSizeFilter.swift
//  Mindbox
//
//  Created by vailence on 07.09.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

protocol ElementsSizeFilterProtocol {
    func filter(_ size: ContentElementSizeDTO?) throws -> ContentElementSize
}

final class ElementSizeFilterService: ElementsSizeFilterProtocol {
    enum Constants {
        static let defaultSize = ContentElementSize(kind: .dp, width: 24, height: 24)
    }
    
    func filter(_ size: ContentElementSizeDTO?) throws -> ContentElementSize {
        guard let size = size else {
            return Constants.defaultSize
        }
        
        switch size.kind {
            case .dp:
                if let height = size.height,
                   let width = size.width,
                   height >= 0,
                   width >= 0 {
                    return ContentElementSize(kind: size.kind, width: width, height: height)
                }
            case .unknown:
                return Constants.defaultSize
        }
        
        throw CustomDecodingError.unknownType("ElementSizeFilterService validation not passed. In-app will be ignored.")
    }
}
