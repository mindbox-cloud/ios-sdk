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
@MainActor
struct ForegroundStopwatchTests {

    private let nc = NotificationCenter()
    private let clock = TestClock()

    private func makeStopwatch(inBackground: Bool = false) -> ForegroundStopwatch {
        ForegroundStopwatch(notificationCenter: nc, now: { clock.now }, isInBackground: { inBackground })
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

    @Test("stop() removes the activation observer too: an activation after it opens nothing")
    func stop_removesTheActivationObserver() throws {
        let stopwatch = makeStopwatch(inBackground: true)

        stopwatch.stop()
        nc.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        clock.advance(1)

        #expect(stopwatch.elapsed == 0)
    }

    // MARK: - Suspension

    @Test("Suspended time is excluded: the stopwatch counts only between resume and suspend")
    func elapsed_excludesSuspendedTime() throws {
        let stopwatch = makeStopwatch()

        clock.advance(0.25)
        stopwatch.suspend()
        clock.advance(40)
        stopwatch.resume()
        clock.advance(0.5)

        #expect(stopwatch.elapsed == 0.75)
        stopwatch.stop()
    }

    @Test("Elapsed while suspended does not count the suspension so far")
    func elapsed_duringSuspension_excludesCurrentSuspension() throws {
        let stopwatch = makeStopwatch()

        clock.advance(0.25)
        stopwatch.suspend()
        clock.advance(40)

        #expect(stopwatch.elapsed == 0.25)
        stopwatch.stop()
    }

    @Test("A background inside a suspension is not subtracted twice")
    func elapsed_backgroundInsideSuspension_countedOnce() throws {
        let stopwatch = makeStopwatch()

        clock.advance(0.25)
        stopwatch.suspend()
        clock.advance(1)
        enterBackground(for: 2)
        clock.advance(1)
        stopwatch.resume()
        clock.advance(0.5)

        #expect(stopwatch.elapsed == 0.75)
        stopwatch.stop()
    }

    @Test("A suspension that starts in the background and ends after it is excluded in full")
    func elapsed_suspensionOverlappingBackground_excludedInFull() throws {
        let stopwatch = makeStopwatch()

        clock.advance(0.25)
        nc.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        clock.advance(1)
        stopwatch.suspend()
        clock.advance(1)
        nc.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        clock.advance(3)
        stopwatch.resume()
        clock.advance(0.5)

        #expect(stopwatch.elapsed == 0.75)
        stopwatch.stop()
    }

    @Test("A stopwatch created in the background starts counting at the foreground")
    func elapsed_createdInBackground_countsFromTheForeground() throws {
        let stopwatch = makeStopwatch(inBackground: true)

        clock.advance(5)
        nc.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        clock.advance(0.25)

        #expect(stopwatch.elapsed == 0.25)
        stopwatch.stop()
    }

    @Test("A stopwatch that missed the foreground notification starts counting when the app becomes active")
    func elapsed_createdInBackground_countsFromTheActivation() throws {
        let stopwatch = makeStopwatch(inBackground: true)

        clock.advance(5)
        nc.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        clock.advance(0.25)

        #expect(stopwatch.elapsed == 0.25)
        stopwatch.stop()
    }

    @Test("A second suspend changes nothing: one resume reopens the count")
    func suspend_twice_oneResumeReopensTheCount() throws {
        let stopwatch = makeStopwatch()

        clock.advance(0.25)
        stopwatch.suspend()
        stopwatch.suspend()
        clock.advance(10)
        stopwatch.resume()
        clock.advance(0.5)

        #expect(stopwatch.elapsed == 0.75)
        stopwatch.stop()
    }

    @Test("A resume in the background waits for the foreground")
    func resume_inBackground_waitsForTheForeground() throws {
        let stopwatch = makeStopwatch()

        clock.advance(0.25)
        nc.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        stopwatch.suspend()
        clock.advance(1)
        stopwatch.resume()
        clock.advance(2)
        nc.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        clock.advance(0.5)

        #expect(stopwatch.elapsed == 0.75)
        stopwatch.stop()
    }

    @Test("Resume on a running stopwatch changes nothing")
    func resume_whileRunning_isANoOp() throws {
        let stopwatch = makeStopwatch()

        clock.advance(0.25)
        stopwatch.resume()
        clock.advance(0.25)

        #expect(stopwatch.elapsed == 0.5)
        stopwatch.stop()
    }
}
