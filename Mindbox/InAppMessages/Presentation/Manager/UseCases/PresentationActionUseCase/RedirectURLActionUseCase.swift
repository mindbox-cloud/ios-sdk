//
//  RedirectURLActionUseCase.swift
//  Mindbox
//
//  Created by vailence on 18.07.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

final class RedirectURLActionUseCase: PresentationActionUseCaseProtocol {

    private let model: RedirectUrlLayerAction

    init(model: RedirectUrlLayerAction) {
        self.model = model
    }

    func execute() -> (url: URL?, payload: String)? {
        guard !model.value.isEmpty || !model.intentPayload.isEmpty else {
            Logger.common(message: "Redirect URL and Payload are empty.", category: .inAppMessages)
            return nil
        }
        return (URL(string: model.value), model.intentPayload)
    }
}
