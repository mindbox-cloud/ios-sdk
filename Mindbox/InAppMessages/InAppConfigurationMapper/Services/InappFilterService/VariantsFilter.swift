//
//  VariantsFilter.swift
//  Mindbox
//
//  Created by vailence on 07.09.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

protocol VariantFilterProtocol {
    func filter(_ variants: [MindboxFormVariantDTO]?) throws -> [MindboxFormVariant]
}

final class VariantFilterService: VariantFilterProtocol {

    private let layersFilter: LayersFilterProtocol
    private let elementsFilter: ElementsFilterProtocol
    private let contentPositionFilter: ContentPositionFilterProtocol

    init(layersFilter: LayersFilterProtocol, elementsFilter: ElementsFilterProtocol, contentPositionFilter: ContentPositionFilterProtocol) {
        self.layersFilter = layersFilter
        self.elementsFilter = elementsFilter
        self.contentPositionFilter = contentPositionFilter
    }
    
    private func getWebviewFromPayload(_ payload: String?) -> WebviewFormVariant? {
        guard let payloadData = payload?.data(using: .utf8) else {
            return nil
        }
        
        do {
            let layerProtocol: WebviewContentBackgroundLayer = try JSONDecoder().decode(WebviewContentBackgroundLayer.self, from: payloadData)
            
            let layer = try ContentBackgroundLayer(type: .webview, layer: layerProtocol)
            
            let backgroundModel = ContentBackground(layers: [layer])
            let contentModel = WebviewFormVariantContent(background: backgroundModel)
            return WebviewFormVariant(content: contentModel)
        } catch {
            return nil
        }
    }

    func filter(_ variants: [MindboxFormVariantDTO]?) throws -> [MindboxFormVariant] {
        var resultVariants: [MindboxFormVariant] = []
        guard let variants = variants else {
            throw CustomDecodingError.unknownType("VariantFilterService validation not passed.")
        }

        for variant in variants {
            switch variant {
                case .modal(let modalFormVariantDTO):
                    guard let content = modalFormVariantDTO.content,
                          let background = content.background else {
                        throw CustomDecodingError.unknownType("VariantFilterService validation not passed.")
                    }
                
                    let filteredLayers = try layersFilter.filter(background.layers)
                    let fileterdElements = try elementsFilter.filter(content.elements)
                
                    var payload: String?
                
                    switch filteredLayers.first {
                        case .image(let image):
                        switch image.action {
                        case .redirectUrl(let redirectUrlLayerAction):
                            payload = redirectUrlLayerAction.intentPayload
                            default:
                                break
                        }
                        default:
                        break
                    }
                
                    let webViewFormVariant = getWebviewFromPayload(payload)
                    
                    if webViewFormVariant != nil {
                        let mindboxFormVariant = try MindboxFormVariant(type: .webview, webviewVariant: webViewFormVariant)
                        resultVariants.append(mindboxFormVariant)
                    } else {
                        let backgroundModel = ContentBackground(layers: filteredLayers)

                        let contentModel = InappFormVariantContent(background: backgroundModel, elements: fileterdElements)
                        let modalFormVariantModel = ModalFormVariant(content: contentModel)
                        let mindboxFormVariant = try MindboxFormVariant(type: .modal, modalVariant: modalFormVariantModel)
                        resultVariants.append(mindboxFormVariant)
                    }
                case .webview(let modalFormVariantDTO):
                    guard let content = modalFormVariantDTO.content,
                          let background = content.background else {
                        throw CustomDecodingError.unknownType("VariantFilterService validation not passed.")
                    }

                    let filteredLayers = try layersFilter.filter(background.layers)

                    let backgroundModel = ContentBackground(layers: filteredLayers)

                    let contentModel = WebviewFormVariantContent(background: backgroundModel)
                    let webviewFormVariantModel = WebviewFormVariant(content: contentModel)
                    let mindboxFormVariant = try MindboxFormVariant(type: .webview, webviewVariant: webviewFormVariantModel)
                        resultVariants.append(mindboxFormVariant)
                case .snackbar(let snackbarFormVariant):
                    guard let content = snackbarFormVariant.content,
                          let background = content.background else {
                        throw CustomDecodingError.unknownType("VariantFilterService validation not passed.")
                    }

                    let filteredLayers = try layersFilter.filter(background.layers)
                    let filteredElements = try elementsFilter.filter(content.elements)
                    let contentPosition = try contentPositionFilter.filter(content.position)

                    let backgroundModel = ContentBackground(layers: filteredLayers)
                    let contentModel = SnackbarFormVariantContent(background: backgroundModel,
                                                                   position: contentPosition,
                                                                   elements: filteredElements)
                    let snackbarFormVariant = SnackbarFormVariant(content: contentModel)
                    let mindboxFormVariant = try MindboxFormVariant(type: .snackbar, snackbarVariant: snackbarFormVariant)
                    resultVariants.append(mindboxFormVariant)
                case .unknown:
                    Logger.common(message: "Unknown type of variant. Variant will be skipped.", level: .debug, category: .inAppMessages)
                    continue
            }
        }

        return resultVariants
    }
}
