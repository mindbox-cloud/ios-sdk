//
//  SessionManager.swift
//  Mindbox
//
//  Created by Ihor Kandaurov on 14.05.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import UIKit
import MindboxLogger

final class MBSessionManager {

    var sessionHandler: ((Bool) -> Void)?
    var isActiveNow: Bool { return isActive }

    private let trackVisitManager: TrackVisitSpecificTrackProtocol

    init(trackVisitManager: TrackVisitSpecificTrackProtocol) {
        self.trackVisitManager = trackVisitManager
        subscribe()
    }

    private var isActive: Bool = false {
        didSet {
            guard isActive, isActive != oldValue else { return }
            sessionHandler?(isActive)
        }
    }

    private func subscribe() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.isActive = true
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.isActive = false
        }

        NotificationCenter.default.addObserver(
            forName: .initializationCompleted,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            guard let self else { return }
            if self.isActive {
                self.sessionHandler?(isActive)
            }
        }
    }
}

// MARK: - SessionManager

extension MBSessionManager: SessionManager {
    func trackDirect() {
        do {
            try trackVisitManager.trackDirect()
        } catch {
            Logger.common(message: "Track Visit Direct failed with error: \(error)", level: .info, category: .visit)
        }
    }

    func trackForeground() {
        do {
            try trackVisitManager.trackForeground()
        } catch {
            Logger.common(message: "Track Visit Foreground failed with error: \(error)", level: .info, category: .visit)
        }
    }
}
