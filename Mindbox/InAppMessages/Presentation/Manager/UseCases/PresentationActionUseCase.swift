//
//  PresentationActionUseCase.swift
//  Mindbox
//
//  Created by vailence on 18.07.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

final class PresentationActionUseCase {

    private let tracker: InAppMessagesTrackerProtocol

    init(tracker: InAppMessagesTrackerProtocol) {
        self.tracker = tracker
    }

    private var clickTracked = false
    
    func onTapAction(
        id: String,
        value: String,
        payload: String,
        onTap: @escaping InAppMessageTapAction,
        close: @escaping () -> Void
    ) {
        Logger.common(message: "Presentation completed", level: .debug, category: .inAppMessages)
        if !clickTracked {
            do {
                try tracker.trackClick(id: id)
                clickTracked = true
                Logger.common(message: "Track InApp.Click. Id \(id)", level: .info, category: .notification)
            } catch {
                Logger.common(message: "Track InApp.Click failed with error: \(error)", level: .error, category: .notification)
            }
        }
        
        if value.isEmpty && payload.isEmpty {
            Logger.common(message: "Redirect URL and Payload are empty.", category: .inAppMessages)
        } else {
            let url = URL(string: value)
            onTap(url, payload)
            close()
        }
    }
}
