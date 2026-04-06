//
//  ForegroundStopwatchTests.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 27.03.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
import UIKit
@testable import Mindbox

@Suite("ForegroundStopwatch tests")
struct ForegroundStopwatchTests {

    @Test("Elapsed time increases while in foreground")
    func elapsed_inForeground_increases() throws {
        let stopwatch = ForegroundStopwatch()
        let first = stopwatch.elapsed
        Thread.sleep(forTimeInterval: 0.05)
        let second = stopwatch.elapsed
        #expect(second > first)
        stopwatch.stop()
    }

    @Test("Background time is excluded from elapsed")
    func elapsed_excludesBackgroundTime() throws {
        let nc = NotificationCenter()
        let stopwatch = ForegroundStopwatch(notificationCenter: nc)

        Thread.sleep(forTimeInterval: 0.05)
        let beforeBackground = stopwatch.elapsed

        nc.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        Thread.sleep(forTimeInterval: 0.2)
        nc.post(name: UIApplication.willEnterForegroundNotification, object: nil)

        let afterForeground = stopwatch.elapsed

        let delta = afterForeground - beforeBackground
        #expect(delta < 0.1, "Expected background time (~0.2s) to be excluded, but delta was \(delta)")
        stopwatch.stop()
    }

    @Test("Elapsed during background does not count background time")
    func elapsed_duringBackground_excludesCurrentBackgroundTime() throws {
        let nc = NotificationCenter()
        let stopwatch = ForegroundStopwatch(notificationCenter: nc)

        Thread.sleep(forTimeInterval: 0.05)
        let beforeBackground = stopwatch.elapsed

        nc.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        Thread.sleep(forTimeInterval: 0.2)

        let duringBackground = stopwatch.elapsed
        let delta = duringBackground - beforeBackground
        #expect(delta < 0.1, "Expected in-progress background time to be excluded, but delta was \(delta)")
        stopwatch.stop()
    }

    @Test("Multiple background sessions are all excluded")
    func elapsed_multipleBackgroundSessions_allExcluded() throws {
        let nc = NotificationCenter()
        let stopwatch = ForegroundStopwatch(notificationCenter: nc)

        let start = stopwatch.elapsed

        nc.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        Thread.sleep(forTimeInterval: 0.1)
        nc.post(name: UIApplication.willEnterForegroundNotification, object: nil)

        nc.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        Thread.sleep(forTimeInterval: 0.1)
        nc.post(name: UIApplication.willEnterForegroundNotification, object: nil)

        let end = stopwatch.elapsed
        let delta = end - start
        #expect(delta < 0.1, "Expected ~0.2s background time to be excluded, but delta was \(delta)")
        stopwatch.stop()
    }

    @Test("Stop removes observers and elapsed freezes behavior")
    func stop_removesObservers() throws {
        let nc = NotificationCenter()
        let stopwatch = ForegroundStopwatch(notificationCenter: nc)

        Thread.sleep(forTimeInterval: 0.05)
        stopwatch.stop()

        nc.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        Thread.sleep(forTimeInterval: 0.1)
        nc.post(name: UIApplication.willEnterForegroundNotification, object: nil)

        let elapsed = stopwatch.elapsed
        #expect(elapsed >= 0.05)
    }
}
