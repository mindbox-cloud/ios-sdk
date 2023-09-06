//
//  InappsFilterService.swift
//  Mindbox
//
//  Created by vailence on 06.09.2023.
//

import Foundation
import MindboxLogger

protocol InappsFilterServiceProtocol {
//    func
}

class InappsFilterService: InappsFilterServiceProtocol {
    
    enum Constants {
        static let elementSize = ContentElementSize(kind: .dp, width: 24, height: 24)
        static let elementPositionMargin = ContentElementPositionMargin(kind: .proportion, top: 0.02, right: 0.02, left: 0.02, bottom: 0.02)
        static let defaultColor = "#000000"
        static let lineWidth = 1

    }
    
    func filter(inapps: [InAppDTO]?) -> [InApp] {
        guard let inapps = inapps else {
            return []
        }
        
        var filteredInapps = [InApp]()
        for inapp in inapps {
            guard let variants = inapp.form.variants else {
                Logger.common(message: "Variants cannot be empty. Inapp will be ignored.")
                continue
            }
            
            var isValidInapp = true
            var variantsArray = [MindboxFormVariant]()
            variantsLoop: for variant in variants {
                switch variant {
                    case .modal(let modalFormVariant):
                        guard let content = modalFormVariant.content,
                              let background = content.background,
                              let layers = background.layers
                        else {
                            isValidInapp = false
                            Logger.common(message: "Something went wrong. Some validations are not passed.")
                            break variantsLoop
                        }
                        
                        let filteredLayers = filterLayers(layers)
                        if filteredLayers.isEmpty {
                            isValidInapp = false
                            break variantsLoop
                        }
                        
                        let backgroundModel = ContentBackground(layers: filteredLayers)
                        guard let elementsModel = convertElements(content.elements) else {
                            break variantsLoop
                        }
                        let contentModel = InappFormVariantContent(background: backgroundModel, elements: elementsModel)
                        let modalFormVariantModel = ModalFormVariant(content: contentModel)
                        do {
                            let mindboxFormVariant = try MindboxFormVariant(type: .modal, modalVariant: modalFormVariantModel)
                            variantsArray.append(mindboxFormVariant)
                        } catch {
                            print(error)
                        }
                    case .snackbar:
                        break
                    case .unknown:
                        continue
                }
            }
            
            if isValidInapp && !variantsArray.isEmpty {
                let formModel = InAppForm(variants: variantsArray)
                let inapp = InApp(id: inapp.id, sdkVersion: inapp.sdkVersion, targeting: inapp.targeting, form: formModel)
                filteredInapps.append(inapp)
            }
        }
        
        return filteredInapps
    }
    
    private func filterLayers(_ layers: [ContentBackgroundLayerDTO]) -> [ContentBackgroundLayer] {
        var layersArray = [ContentBackgroundLayer]()
        for layer in layers {
            switch layer {
                case .image(let imageContentBackgroundLayerDTO):
                    if let action = convertAction(imageContentBackgroundLayerDTO.action),
                        let source = convertSource(imageContentBackgroundLayerDTO.source) {
                        let imageLayer = ImageContentBackgroundLayer(action: action, source: source)
                        do {
                            let newLayer = try ContentBackgroundLayer(type: layer.layerType, imageLayer: imageLayer)
                            layersArray.append(newLayer)
                        } catch {
                            Logger.common(message: "filterLayers error: [\(error)]", level: .error, category: .inAppMessages)
                        }
                    } else {
                        return []
                    }
                case .unknown:
                    break
            }
        }
        
        return layersArray.filter { $0.layerType != .unknown }
    }
    
    private func convertAction(_ action: ContentBackgroundLayerActionDTO?) -> ContentBackgroundLayerAction? {
        guard let action = action,
              action.actionType != .unknown else {
            return nil
        }
        
        switch action {
            case .redirectUrl(let redirectUrlLayerAction):
                if let value = redirectUrlLayerAction.value, let payload = redirectUrlLayerAction.intentPayload {
                    do {
                        let redirectUrlLayerActionModel = RedirectUrlLayerAction(intentPayload: payload, value: value)
                        return try ContentBackgroundLayerAction(type: .redirectUrl, redirectModel: redirectUrlLayerActionModel)
                    } catch {
                        Logger.common(message: "convertAction error: [\(error)]", level: .error, category: .inAppMessages)
                    }
                }
            case .unknown:
                break
        }
        
        return nil
    }
    
    private func convertSource(_ source: ContentBackgroundLayerSourceDTO?) -> ContentBackgroundLayerSource? {
        guard let source = source,
              source.sourceType != .unknown else {
            return nil
        }
        
        switch source {
            case .url(let urlLayerSource):
                if let value = urlLayerSource.value {
                    do {
                        let urlLayerSourceModel = UrlLayerSource(value: value)
                        return try ContentBackgroundLayerSource(type: .url, urlModel: urlLayerSourceModel)
                    } catch {
                        Logger.common(message: "convertSource error: [\(error)]", level: .error, category: .inAppMessages)
                    }
                }
            case .unknown:
                break
        }
        
        return nil
    }
    
    private func convertElements(_ elements: [ContentElementDTO]?) -> [ContentElement]? {
        guard let elements = elements, !elements.isEmpty else {
            return []
        }
        
        var filteredElements = [ContentElement]()
        
        elementsLoop: for element in elements {
            if element.elementType == .unknown {
                continue
            }
            
            switch element {
                case .closeButton(let closeButtonElement):
                    var customSize: ContentElementSize
                    if let sizeDTO = closeButtonElement.size?.element {
                        if sizeDTO.kind == .unknown {
                            customSize = Constants.elementSize
                        } else if let height = sizeDTO.height,
                           let width = sizeDTO.width,
                           height >= 0,
                           width >= 0 {
                            customSize = ContentElementSize(kind: sizeDTO.kind, width: width, height: height)
                        } else {
                            return nil
                        }
                    } else {
                        customSize = Constants.elementSize
                    }
                    
                    var customPosition: ContentElementPosition
                    if let positionDTO = closeButtonElement.position?.element,
                       let margin = positionDTO.margin?.element {
                        let marginRange: ClosedRange<Double> = 0...1
                        var customMargin: ContentElementPositionMargin
                        if margin.kind == .unknown {
                            customMargin = Constants.elementPositionMargin
                            customPosition = ContentElementPosition(margin: customMargin)
                        } else if let top = margin.top,
                                  let left = margin.left,
                                  let right = margin.right,
                                  let bottom = margin.bottom,
                                  marginRange.contains(top),
                                  marginRange.contains(left),
                                  marginRange.contains(right),
                                  marginRange.contains(bottom) {
                            customMargin = ContentElementPositionMargin(kind: margin.kind, top: top, right: right, left: left, bottom: bottom)
                            customPosition = ContentElementPosition(margin: customMargin)
                        } else {
                            return nil
                        }
                    } else {
                        customPosition = ContentElementPosition(margin: Constants.elementPositionMargin)
                    }
                    
                    do {
                        let customCloseButtonElement = CloseButtonElement(color: closeButtonElement.color?.element ?? Constants.defaultColor,
                                                                          lineWidth: closeButtonElement.lineWidth?.element ?? Constants.lineWidth,
                                                                          size: customSize,
                                                                          position: customPosition)
                        let element = try ContentElement(type: .closeButton, closeButton: customCloseButtonElement)
                        filteredElements.append(element)
                    } catch {
                        Logger.common(message: "convertElements error: [\(error)]", level: .error, category: .inAppMessages)
                    }
                case .unknown:
                    continue elementsLoop
            }
        }
        
        return filteredElements
    }
}
