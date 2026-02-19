//
//  ActionUseCaseFactory.swift
//  Mindbox
//
//  Created by vailence on 14.03.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation

enum ActionUseCaseFactory {

    static func createUseCase(action: ContentBackgroundLayerAction) -> PresentationActionUseCaseProtocol? {
        switch action {
        case .redirectUrl(let model):
            return RedirectURLActionUseCase(model: model)
        case .pushPermission(let model):
            return PushPermissionActionUseCase(model: model)
        case .unknown:
            return nil
        }
    }
}
