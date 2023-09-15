//
//  VariantsFilter.swift
//  Mindbox
//
//  Created by vailence on 07.09.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

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
    
    func filter(_ variants: [MindboxFormVariantDTO]?) throws -> [MindboxFormVariant] {
        var resultVariants: [MindboxFormVariant] = []
        guard let variants = variants else {
            throw CustomDecodingError.unknownType("VariantFilterService validation not passed.")
        }
        
        variantsLoop: for variant in variants {
            switch variant {
                case .modal(let modalFormVariantDTO):
                    guard let content = modalFormVariantDTO.content,
                          let background = content.background else {
                        throw CustomDecodingError.unknownType("VariantFilterService validation not passed.")
                    }
                    
                    let filteredLayers = try layersFilter.filter(background.layers)
                    if filteredLayers.isEmpty {
                        continue variantsLoop
                    }
                    let fileterdElements = try elementsFilter.filter(content.elements)
                    
                    let backgroundModel = ContentBackground(layers: filteredLayers)

                    let contentModel = InappFormVariantContent(background: backgroundModel, elements: fileterdElements)
                    let modalFormVariantModel = ModalFormVariant(content: contentModel)
                    let mindboxFormVariant = try MindboxFormVariant(type: .modal, modalVariant: modalFormVariantModel)
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
                    continue
            }
        }
        
        return resultVariants
    }
}
