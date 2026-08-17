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
                case .embedded(let embeddedFormVariantDTO):
                    guard let embeddedFormVariant = makeEmbeddedVariant(from: embeddedFormVariantDTO) else {
                        continue
                    }

                    resultVariants.append(try MindboxFormVariant(type: .embedded, embeddedVariant: embeddedFormVariant))
                case .unknown:
                    Logger.common(message: "Unknown type of variant. Variant will be skipped.", level: .debug, category: .inAppMessages)
                    continue
            }
        }

        return resultVariants
    }

    /// Returns `nil` when the variant cannot address a block, and the caller skips it. An invalid
    /// embedded variant does not throw the way an invalid modal does: a block with no usable place is
    /// inert rather than broken, and taking the whole in-app down for it would also take down the
    /// sibling variants.
    private func makeEmbeddedVariant(from dto: EmbeddedFormVariantDTO) -> EmbeddedFormVariant? {
        // Trimmed, because a place name padded with spaces in the admin panel still means the place
        // the host app asks for. Case is left alone: it has to match.
        let placeSystemName = dto.placeSystemName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !placeSystemName.isEmpty else {
            Logger.common(message: "[EmbeddedVariant] Variant has no place system name. Variant will be skipped.",
                          level: .error, category: .inAppMessages)
            return nil
        }

        guard let content = dto.content, let background = content.background else {
            Logger.common(message: "[EmbeddedVariant] Variant for place '\(placeSystemName)' has no content. Variant will be skipped.",
                          level: .error, category: .inAppMessages)
            return nil
        }

        // Caught, not propagated: a malformed section costs this variant only, not the whole in-app.
        let filteredLayers: [ContentBackgroundLayer]
        let filteredElements: [ContentElement]
        do {
            filteredLayers = try layersFilter.filter(background.layers)
            filteredElements = try elementsFilter.filter(content.elements)
        } catch {
            Logger.common(message: "[EmbeddedVariant] Variant for place '\(placeSystemName)' has invalid content: \(error). Variant will be skipped.",
                          level: .error, category: .inAppMessages)
            return nil
        }

        // The whole block is one web page, so the first webview layer is what it renders. More layers is
        // a configuration mistake rather than a reason to show nothing — the extra ones are ignored and
        // called out in the log (in sync with Android). No webview layer at all is different: there
        // is nothing to render, and the variant cannot address a block.
        guard let webviewLayerIndex = filteredLayers.firstIndex(where: { if case .webview = $0 { return true } else { return false } }) else {
            Logger.common(message: "[EmbeddedVariant] Variant for place '\(placeSystemName)' has no webview layer. Variant will be skipped.",
                          level: .error, category: .inAppMessages)
            return nil
        }

        if filteredLayers.count > 1 {
            Logger.common(message: "[EmbeddedVariant] Variant for place '\(placeSystemName)' has \(filteredLayers.count) layers; the first webview layer is used, the rest are ignored.",
                          level: .error, category: .inAppMessages)
        }

        let backgroundModel = ContentBackground(layers: [filteredLayers[webviewLayerIndex]])
        let contentModel = InappFormVariantContent(background: backgroundModel, elements: filteredElements)

        return EmbeddedFormVariant(content: contentModel, placeSystemName: placeSystemName)
    }
}
