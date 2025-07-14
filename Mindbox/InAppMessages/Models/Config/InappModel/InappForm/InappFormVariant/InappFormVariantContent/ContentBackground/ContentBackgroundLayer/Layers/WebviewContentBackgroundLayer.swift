//
//  ImageContentBackgroundLayer.swift
//  Mindbox
//
//  Created by Egor Kitselyuk on 19.03.2025.
//

import Foundation

struct WebviewContentBackgroundLayerDTO: ContentBackgroundLayerProtocol {
    let baseUrl: String?
    let contentUrl: String?
    let type: String?
    let params: [String: String]?
}

struct WebviewContentBackgroundLayer: ContentBackgroundLayerProtocol {
    let baseUrl: String
    let contentUrl: String
    let type: String?
    let params: [String: String]
}
