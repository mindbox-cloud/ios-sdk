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

// The stopwatch listens on the main queue; posting from it keeps the delivery synchronous, so the
// clock is read after the observer ran and not before.
@Suite("ForegroundStopwatch tests")
@MainActor
struct ForegroundStopwatchTests {

    private let nc = NotificationCenter()
    private let clock = TestClock()

    private func makeStopwatch() -> ForegroundStopwatch {
        ForegroundStopwatch(notificationCenter: nc, now: { clock.now })
    }

    private func enterBackground(for seconds: TimeInterval) {
        nc.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        clock.advance(seconds)
        nc.post(name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    @Test("Elapsed time is the foreground time since the start")
    func elapsed_inForeground_increases() throws {
        let stopwatch = makeStopwatch()
        #expect(stopwatch.elapsed == 0)

        clock.advance(0.5)

        #expect(stopwatch.elapsed == 0.5)
        stopwatch.stop()
    }

    @Test("Background time is excluded from elapsed")
    func elapsed_excludesBackgroundTime() throws {
        let stopwatch = makeStopwatch()

        clock.advance(0.25)
        enterBackground(for: 2)

        #expect(stopwatch.elapsed == 0.25)
        stopwatch.stop()
    }

    @Test("Elapsed during background does not count the background so far")
    func elapsed_duringBackground_excludesCurrentBackgroundTime() throws {
        let stopwatch = makeStopwatch()

        clock.advance(0.25)
        nc.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        clock.advance(2)

        #expect(stopwatch.elapsed == 0.25)
        stopwatch.stop()
    }

    @Test("Multiple background sessions are all excluded")
    func elapsed_multipleBackgroundSessions_allExcluded() throws {
        let stopwatch = makeStopwatch()

        enterBackground(for: 1)
        clock.advance(0.25)
        enterBackground(for: 1)

        #expect(stopwatch.elapsed == 0.25)
        stopwatch.stop()
    }

    @Test("Stop removes the observers: a background after it is no longer excluded")
    func stop_removesObservers() throws {
        let stopwatch = makeStopwatch()

        clock.advance(0.25)
        stopwatch.stop()
        enterBackground(for: 1)

        #expect(stopwatch.elapsed == 1.25)
    }
}
