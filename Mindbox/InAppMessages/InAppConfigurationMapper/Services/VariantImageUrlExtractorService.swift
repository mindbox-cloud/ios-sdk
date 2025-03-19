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
            case .webview(_):
                urlString.append("https://mobile-static.mindbox.ru/f3d41714973639a3e18788e4b582f451d0952f723ccd9f33092d841bbb9e5b95/79cbec7d53bad5609d69223f3ed914fb6928eac6f6107b226c6eec657945e9a4.jpg")
                break
            case .unknown:
                break
            }
        }
    }
}
