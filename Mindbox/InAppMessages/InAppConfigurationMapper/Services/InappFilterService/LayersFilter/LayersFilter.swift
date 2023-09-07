//
//  LayersFilter.swift
//  Mindbox
//
//  Created by vailence on 07.09.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

protocol LayersFilterProtocol {
    func filter(_ layers: [ContentBackgroundLayerDTO]?) throws -> [ContentBackgroundLayer]?
}

final class LayersFilterService: LayersFilterProtocol {
    private let actionFilter: LayerActionFilterProtocol
    private let sourceFilter: LayersSourceFilterProtocol
    
    init(actionFilter: LayerActionFilterProtocol, sourceFilter: LayersSourceFilterProtocol) {
        self.actionFilter = actionFilter
        self.sourceFilter = sourceFilter
    }
    
    func filter(_ layers: [ContentBackgroundLayerDTO]?) throws -> [ContentBackgroundLayer]? {
        var filteredLayers: [ContentBackgroundLayer] = []
        
        guard let layers = layers else {
            return nil
        }
        
        for layer in layers {
            switch layer {
                case .image(let imageContentBackgroundLayerDTO):
                    if let action = try actionFilter.filter(imageContentBackgroundLayerDTO.action),
                       let source = try sourceFilter.filter(imageContentBackgroundLayerDTO.source) {
                        let imageLayer = ImageContentBackgroundLayer(action: action, source: source)
                        let newLayer = try ContentBackgroundLayer(type: layer.layerType, imageLayer: imageLayer)
                        filteredLayers.append(newLayer)
                    } else {
                        return []
                    }
                case .unknown:
                    break
            }
        }
        
        return filteredLayers.filter { $0.layerType != .unknown }
    }
}
