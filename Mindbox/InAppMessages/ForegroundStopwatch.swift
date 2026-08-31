//
//  ForegroundStopwatch.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 27.03.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import QuartzCore
import UIKit

/// A stopwatch that only counts time while the app is in the foreground.
/// Background time (between `didEnterBackground` and `willEnterForeground`) is excluded from `elapsed`.
final class ForegroundStopwatch {
    private let now: () -> CFTimeInterval
    private let startTime: CFTimeInterval
    private var totalBackgroundDuration: CFTimeInterval = 0
    private var backgroundEntryTime: CFTimeInterval?

    private var bgObserver: NSObjectProtocol?
    private var fgObserver: NSObjectProtocol?

    private let notificationCenter: NotificationCenter

    init(notificationCenter: NotificationCenter = .default,
         now: @escaping () -> CFTimeInterval = { CACurrentMediaTime() }) {
        self.notificationCenter = notificationCenter
        self.now = now
        self.startTime = now()

        bgObserver = notificationCenter.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.backgroundEntryTime = self.now()
        }

        fgObserver = notificationCenter.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, let entryTime = self.backgroundEntryTime else { return }
            self.totalBackgroundDuration += self.now() - entryTime
            self.backgroundEntryTime = nil
        }
    }

    /// Elapsed foreground-only time since the stopwatch was created.
    var elapsed: TimeInterval {
        var currentBackgroundDuration = totalBackgroundDuration
        if let entryTime = backgroundEntryTime {
            currentBackgroundDuration += now() - entryTime
        }
        return now() - startTime - currentBackgroundDuration
    }

    /// Stops the stopwatch and removes notification observers.
    func stop() {
        if let bgObserver { notificationCenter.removeObserver(bgObserver) }
        if let fgObserver { notificationCenter.removeObserver(fgObserver) }
        bgObserver = nil
        fgObserver = nil
    }

    deinit {
        stop()
    }
}
