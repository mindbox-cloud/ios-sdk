//
//  PushPermissionActionUseCase.swift
//  Mindbox
//
//  Created by vailence on 14.03.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation

extension ContentBackgroundLayerAction {
    /// Delegates to `ActionUseCaseFactory` to extract URL/payload and handle side effects.
    /// Returns `nil` for `.unknown` or empty redirect actions (no callback should be invoked).
    func handleTap() -> (url: URL?, payload: String)? {
        guard let useCase = ActionUseCaseFactory.createUseCase(action: self) else {
            return nil
        }
        return useCase.execute()
    }
}

final class PushPermissionActionUseCase: PresentationActionUseCaseProtocol {

    private let model: PushPermissionLayerAction

    init(model: PushPermissionLayerAction) {
        self.model = model
    }

    func execute() -> (url: URL?, payload: String)? {
        PushPermissionHelper.requestOrOpenSettings()
        return (nil, model.intentPayload)
    }
}

enum PushPermissionHelper {

    private static let handler = PushNotificationsPermissionHandler()

    static func requestOrOpenSettings() {
        handler.request { _ in }
    }
}
