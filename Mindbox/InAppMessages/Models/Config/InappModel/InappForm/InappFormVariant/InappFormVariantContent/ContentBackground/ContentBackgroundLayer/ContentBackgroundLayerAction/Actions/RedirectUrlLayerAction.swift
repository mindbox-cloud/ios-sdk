//
//  RedirectUrlLayerAction.swift
//  Mindbox
//
//  Created by vailence on 10.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

struct RedirectUrlLayerActionDTO: ContentBackgroundLayerActionProtocol {
    let intentPayload: String?
    let value: String?
}

struct RedirectUrlLayerAction: ContentBackgroundLayerActionProtocol {
    let intentPayload: String
    let value: String
}
