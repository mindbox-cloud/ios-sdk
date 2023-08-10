//
//  VariantImageUrlExtractorService.swift
//  Mindbox
//
//  Created by vailence on 10.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

class VariantImageUrlExtractorService {
    func extractImageURL(from variant: MindboxFormVariant) -> String? {
        var urlString: String?
        switch variant {
        case .modal(let modalModel):
            let modalModel = modalModel.content.background.layers.elements.first(where: {
                switch $0 {
                case .image(let imageModel):
                    switch imageModel.source {
                    case .url(let urlModel):
                            urlString = urlModel.value
                        return true
                    case .unknown:
                        return false
                    }
                case .unknown:
                    return false
                }
            })
        case .unknown:
            return nil
        }
        
        return urlString
    }
}
