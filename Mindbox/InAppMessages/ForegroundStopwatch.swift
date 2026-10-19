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

final class ForegroundStopwatch {
    private let now: () -> CFTimeInterval

    private var accumulated: CFTimeInterval = 0
    private var runningSince: CFTimeInterval?

    private var isInBackground = false
    private var isSuspended = false

    private var bgObserver: NSObjectProtocol?
    private var fgObserver: NSObjectProtocol?
    private var activeObserver: NSObjectProtocol?

    private let notificationCenter: NotificationCenter

    init(notificationCenter: NotificationCenter = .default,
         now: @escaping () -> CFTimeInterval = { CACurrentMediaTime() },
         isInBackground: () -> Bool = { UIApplication.shared.applicationState == .background }) {
        self.notificationCenter = notificationCenter
        self.now = now
        self.isInBackground = isInBackground()
        self.runningSince = self.isInBackground ? nil : now()

        bgObserver = notificationCenter.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.isInBackground = true
            self.settle()
        }

        let foreground: (Notification) -> Void = { [weak self] _ in
            guard let self else { return }
            self.isInBackground = false
            self.settle()
        }
        fgObserver = notificationCenter.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main,
            using: foreground
        )
        // applicationState still reads .background during willEnterForeground, and an observer added mid-delivery misses that post.
        activeObserver = notificationCenter.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main,
            using: foreground
        )
    }

    var elapsed: TimeInterval {
        accumulated + (runningSince.map { now() - $0 } ?? 0)
    }

    func suspend() {
        isSuspended = true
        settle()
    }

    func resume() {
        isSuspended = false
        settle()
    }

    func stop() {
        if let bgObserver { notificationCenter.removeObserver(bgObserver) }
        if let fgObserver { notificationCenter.removeObserver(fgObserver) }
        if let activeObserver { notificationCenter.removeObserver(activeObserver) }
        bgObserver = nil
        fgObserver = nil
        activeObserver = nil
    }

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
