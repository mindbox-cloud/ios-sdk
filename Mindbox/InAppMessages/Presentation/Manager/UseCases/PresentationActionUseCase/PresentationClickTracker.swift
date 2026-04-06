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
    func execute() -> (url: URL?, payload: String)?
}

class PresentationClickTracker {
    private let tracker: InAppMessagesTrackerProtocol

    init(tracker: InAppMessagesTrackerProtocol) {
        self.tracker = tracker
    }

    func trackClick(id: String) {
        if SessionTemporaryStorage.shared.lastInappClickedID == id {
            return
        }
        
        SessionTemporaryStorage.shared.lastInappClickedID = id
        
        do {
            try tracker.trackClick(id: id)
            Logger.common(message: "Track InApp.Click. Id \(id)", level: .info, category: .notification)
        } catch {
            Logger.common(message: "Track InApp.Click failed with error: \(error)", level: .error, category: .notification)
        }
    }
}
