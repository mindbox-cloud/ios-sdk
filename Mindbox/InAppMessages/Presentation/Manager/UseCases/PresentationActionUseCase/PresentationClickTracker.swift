//
//  PresentationClickTracker.swift
//  Mindbox
//
//  Created by vailence on 14.03.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

protocol PresentationActionUseCaseProtocol {
    func onTapAction(
        id: String,
        onTap: @escaping InAppMessageTapAction,
        close: @escaping () -> Void
    )
}

class PresentationClickTracker {
    private let tracker: InAppMessagesTrackerProtocol

    init(tracker: InAppMessagesTrackerProtocol) {
        self.tracker = tracker
    }

    func trackClick(id: String) {
        guard !SessionTemporaryStorage.shared.clickTracked else { return }

        do {
            try tracker.trackClick(id: id)
            SessionTemporaryStorage.shared.clickTracked = true
            Logger.common(message: "Track InApp.Click. Id \(id)", level: .info, category: .notification)
        } catch {
            Logger.common(message: "Track InApp.Click failed with error: \(error)", level: .error, category: .notification)
        }
    }
}
