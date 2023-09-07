//
//  LayersSourceFilter.swift
//  Mindbox
//
//  Created by vailence on 07.09.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

protocol LayersSourceFilterProtocol {
    func filter(_ source: ContentBackgroundLayerSourceDTO?) throws -> ContentBackgroundLayerSource?
}

final class LayersSourceFilterService: LayersSourceFilterProtocol {
    func filter(_ source: ContentBackgroundLayerSourceDTO?) throws -> ContentBackgroundLayerSource? {
        guard let source = source,
              source.sourceType != .unknown else {
            return nil
        }
        
        switch source {
            case .url(let urlLayerSource):
                if let value = urlLayerSource.value {
                    let urlLayerSourceModel = UrlLayerSource(value: value)
                    return try ContentBackgroundLayerSource(type: .url, urlModel: urlLayerSourceModel)
                }
            case .unknown:
                break
        }
        
        return nil
    }
}
