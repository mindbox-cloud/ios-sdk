//
//  LayerActionFilter.swift
//  Mindbox
//
//  Created by vailence on 07.09.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

protocol LayerActionFilterProtocol {
    func filter(_ action: ContentBackgroundLayerActionDTO?) throws -> ContentBackgroundLayerAction
}

final class LayerActionFilterService: LayerActionFilterProtocol {
    func filter(_ action: ContentBackgroundLayerActionDTO?) throws -> ContentBackgroundLayerAction {
        guard let action = action,
              action.actionType != .unknown else {
            throw CustomDecodingError.unknownType("LayerActionFilterService validation not passed.")
        }
        
        switch action {
            case .pushPermission(let pushPermissionAction):
                if let payload = pushPermissionAction.intentPayload {
                    let pushPermissionActionModel = PushPermissionLayerAction(intentPayload: payload)
                    return try ContentBackgroundLayerAction(type: .pushPermission, pushPermissionModel: pushPermissionActionModel)
                }
            case .redirectUrl(let redirectUrlLayerAction):
                if let value = redirectUrlLayerAction.value, let payload = redirectUrlLayerAction.intentPayload {
                    let redirectUrlLayerActionModel = RedirectUrlLayerAction(intentPayload: payload, value: value)
                    return try ContentBackgroundLayerAction(type: .redirectUrl, redirectModel: redirectUrlLayerActionModel)
                }
            case .unknown:
                break
        }
        
        throw CustomDecodingError.unknownType("LayerActionFilterService validation not passed.")
    }
}
