//
//  SessionManager.swift
//  Mindbox
//
//  Created by Ihor Kandaurov on 14.05.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import UIKit
import MindboxLogger

final class SessionManager {
    init(trackVisitManager: TrackVisitManager) {
        self.trackVisitManager = trackVisitManager

        subscribe()
    }

    var sessionHandler: ((Bool) -> Void)?
    var isActiveNow: Bool { return isActive }
    
    func trackDirect() {
        do {
            try trackVisitManager.trackDirect()
        } catch {
            Logger.common(message: "Track Visit failed with error: \(error)", level: .info, category: .visit)
        }
    }

    func trackForeground() {
        do {
            try trackVisitManager.trackForeground()
        } catch {
            Logger.common(message: "Track Visit failed with error: \(error)", level: .info, category: .visit)
        }
    }

    private let trackVisitManager: TrackVisitManager

    private var isActive: Bool = false {
        didSet {
            guard isActive, isActive != oldValue else { return }
            sessionHandler?(isActive)
            trackDirect()
        }
    }

    private func subscribe() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: nil) { [weak self] _ in
            if UIApplication.shared.applicationState == .active {
                self?.isActive = true
            }
        }
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: nil) { [weak self] _ in
            self?.isActive = false
        }
    }
}
