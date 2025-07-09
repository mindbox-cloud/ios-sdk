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
    func filter(_ layers: [ContentBackgroundLayerDTO]?) throws -> [ContentBackgroundLayer]
}

final class LayersFilterService: LayersFilterProtocol {
    private let actionFilter: LayerActionFilterProtocol
    private let sourceFilter: LayersSourceFilterProtocol

    init(actionFilter: LayerActionFilterProtocol, sourceFilter: LayersSourceFilterProtocol) {
        self.actionFilter = actionFilter
        self.sourceFilter = sourceFilter
    }

    func filter(_ layers: [ContentBackgroundLayerDTO]?) throws -> [ContentBackgroundLayer] {
        var filteredLayers: [ContentBackgroundLayer] = []

        guard let layers = layers else {
            throw CustomDecodingError.unknownType("LayersFilterService validation not passed.")
        }

        for layer in layers {
            switch layer {
                case .image(let imageContentBackgroundLayerDTO):
                    let action = try actionFilter.filter(imageContentBackgroundLayerDTO.action)
                    let source = try sourceFilter.filter(imageContentBackgroundLayerDTO.source)
                    let imageLayer = ImageContentBackgroundLayer(action: action, source: source)
                    let newLayer = try ContentBackgroundLayer(type: layer.layerType, layer: imageLayer)
                    filteredLayers.append(newLayer)
                case .webview(let webviewContentBackgroundLayerDTO):
                    let baseUrl = webviewContentBackgroundLayerDTO.baseUrl
                    let contentUrl = webviewContentBackgroundLayerDTO.contentUrl
                    let payload = webviewContentBackgroundLayerDTO.payload
                    let redirectUrl = webviewContentBackgroundLayerDTO.redirectUrl
                    let wizardId = webviewContentBackgroundLayerDTO.wizardId
                    let webviewLayer = WebviewContentBackgroundLayer(
                        baseUrl: baseUrl,
                        contentUrl: contentUrl,
                        redirectUrl: redirectUrl,
                        payload: payload,
                        wizardId: wizardId
                    )
                    let newLayer = try ContentBackgroundLayer(type: layer.layerType, layer: webviewLayer)
                    filteredLayers.append(newLayer)
                case .unknown:
                    Logger.common(message: "Unknown type of layer. Layer will be skipped.", level: .debug, category: .inAppMessages)
            }
        }

        if filteredLayers.isEmpty {
            throw CustomDecodingError.unknownType("Layers cannot be empty. In-app will be skipped.")
        }

        return filteredLayers.filter { $0.layerType != .unknown }
    }
}
