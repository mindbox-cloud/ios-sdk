//
//  ImageContentBackgroundLayer.swift
//  Mindbox
//
//  Created by vailence on 10.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

struct ImageContentBackgroundLayerDTO: ContentBackgroundLayerProtocol {
    let action: ContentBackgroundLayerActionDTO?
    let source: ContentBackgroundLayerSourceDTO?
}

struct ImageContentBackgroundLayer: ContentBackgroundLayerProtocol {
    let action: ContentBackgroundLayerAction
    let source: ContentBackgroundLayerSource
}
