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

/// A stopwatch that only counts time while somebody could be looking: the app is in the foreground
/// and the owner has not suspended it. Background time (between `didEnterBackground` and
/// `willEnterForeground`) and suspended time are excluded from `elapsed`, and an overlap of the two
/// is excluded once — the stopwatch is either running or not.
final class ForegroundStopwatch {
    private let now: () -> CFTimeInterval

    /// Running time settled so far; the open run, if any, is added on top.
    private var accumulated: CFTimeInterval = 0
    private var runningSince: CFTimeInterval?

    private var isInBackground = false
    private var isSuspended = false

    private var bgObserver: NSObjectProtocol?
    private var fgObserver: NSObjectProtocol?

    private let notificationCenter: NotificationCenter

    init(notificationCenter: NotificationCenter = .default,
         now: @escaping () -> CFTimeInterval = { CACurrentMediaTime() }) {
        self.notificationCenter = notificationCenter
        self.now = now
        self.runningSince = now()

        bgObserver = notificationCenter.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.isInBackground = true
            self.settle()
        }

        fgObserver = notificationCenter.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.isInBackground = false
            self.settle()
        }
    }

    /// Elapsed running time since the stopwatch was created.
    var elapsed: TimeInterval {
        accumulated + (runningSince.map { now() - $0 } ?? 0)
    }

    /// Stops the count until `resume()`: nobody is looking at what is being measured.
    func suspend() {
        isSuspended = true
        settle()
    }

    /// Resumes the count after `suspend()`; on a running stopwatch it changes nothing.
    func resume() {
        isSuspended = false
        settle()
    }

    /// Stops the stopwatch and removes notification observers.
    func stop() {
        if let bgObserver { notificationCenter.removeObserver(bgObserver) }
        if let fgObserver { notificationCenter.removeObserver(fgObserver) }
        bgObserver = nil
        fgObserver = nil
    }

    /// Brings the open run in line with the gates: opens one when both are clear, closes it otherwise.
    private func settle() {
        let shouldRun = !isInBackground && !isSuspended

        if shouldRun {
            if runningSince == nil {
                runningSince = now()
            }
        } else if let runningSince {
            accumulated += now() - runningSince
            self.runningSince = nil
        }
    }

    deinit {
        stop()
    }
}
