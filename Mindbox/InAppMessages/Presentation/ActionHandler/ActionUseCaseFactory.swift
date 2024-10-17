//
//  ActionUseCaseFactory.swift
//  Mindbox
//
//  Created by vailence on 14.03.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation

protocol UseCaseFactoryProtocol {
    func createUseCase(action: ContentBackgroundLayerAction) -> PresentationActionUseCaseProtocol?
}

class ActionUseCaseFactory: UseCaseFactoryProtocol {
    private let clickTracker: PresentationClickTracker

    init(tracker: InAppMessagesTrackerProtocol) {
        clickTracker = PresentationClickTracker(tracker: tracker)
    }

    func createUseCase(action: ContentBackgroundLayerAction) -> PresentationActionUseCaseProtocol? {
        switch action {
            case .pushPermission(let pushPermissionModel):
                return PushPermissionActionUseCase(tracker: clickTracker, model: pushPermissionModel)
            case .redirectUrl(let redirectModel):
                return RedirectURLActionUseCase(tracker: clickTracker, model: redirectModel)
            case .unknown:
                return nil
        }
    }
}
