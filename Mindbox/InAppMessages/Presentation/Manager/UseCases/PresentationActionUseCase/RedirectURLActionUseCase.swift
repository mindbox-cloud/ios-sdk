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

    private let tracker: PresentationClickTracker
    private let model: RedirectUrlLayerAction

    init(tracker: PresentationClickTracker, model: RedirectUrlLayerAction) {
        self.tracker = tracker
        self.model = model
    }

    func onTapAction(
        id: String,
        onTap: @escaping InAppMessageTapAction,
        close: @escaping () -> Void
    ) {
        tracker.trackClick(id: id)
        if model.value.isEmpty && model.intentPayload.isEmpty {
            Logger.common(message: "Redirect URL and Payload are empty.", category: .inAppMessages)
        } else {
            let url = URL(string: model.value)
            onTap(url, model.intentPayload)
            close()
        }
    }
}
