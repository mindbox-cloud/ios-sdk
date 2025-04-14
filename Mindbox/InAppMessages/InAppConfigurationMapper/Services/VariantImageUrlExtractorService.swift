//
//  VariantImageUrlExtractorService.swift
//  Mindbox
//
//  Created by vailence on 10.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

protocol VariantImageUrlExtractorServiceProtocol {
    func extractImageURL(from variant: MindboxFormVariant) -> [String]
}

class VariantImageUrlExtractorService: VariantImageUrlExtractorServiceProtocol {
    func extractImageURL(from variant: MindboxFormVariant) -> [String] {
        var urlString: [String] = []

        let elements: [ContentBackgroundLayer]

        switch variant {
        case .modal(let modalModel):
            elements = modalModel.content.background.layers
        case .snackbar(let snackbarModel):
            elements = snackbarModel.content.background.layers
        case .webview(let webviewModel):
            elements = webviewModel.content.background.layers
        case .unknown:
            return []
        }

        extractImageURLs(from: elements, into: &urlString)

        return urlString
    }

    private func extractImageURLs(from elements: [ContentBackgroundLayer], into urlString: inout [String]) {
        for element in elements {
            switch element {
            case .image(let imageModel):
                switch imageModel.source {
                case .url(let urlModel):
                    urlString.append(urlModel.value)
                case .unknown:
                    break
                }
            case .webview:
                break
            case .unknown:
                break
            }
        }
    }
}
