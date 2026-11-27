//
//  PushDeliveryConfirmationScheduleTests.swift
//  MindboxTests
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
@_spi(Internal) @testable import Mindbox
#if SWIFT_PACKAGE
@_spi(Internal)
import MindboxShared
#endif

@Suite("Push delivery confirmation schedule")
struct PushDeliveryConfirmationScheduleTests {
    private let schedule = PushDeliveryConfirmationSchedule()

    private func durations(for answers: [PushDeliveryConfirmationAnswer]) -> [TimeInterval?] {
        var previous: PushDeliveryConfirmationPause?
        var result: [TimeInterval?] = []
        for answer in answers {
            let pause = schedule.nextPause(after: answer, previous: previous)
            result.append(pause?.duration)
            previous = pause
        }
        return result
    }

    @Test("K7: failures in a row double the pause up to the cap")
    func failuresDouble() {
        #expect(durations(for: [.failed, .failed, .failed, .failed]) == [10, 20, 40, 80])
        let capped = PushDeliveryConfirmationPause(answer: .failed, duration: 3600)
        #expect(schedule.nextPause(after: .failed, previous: capped)?.duration == 3600)
    }

    @Test("K13: throttles in a row double the pause up to the cap")
    func throttlesDouble() {
        #expect(durations(for: [.throttled, .throttled]) == [200, 400])
        let capped = PushDeliveryConfirmationPause(answer: .throttled, duration: 3600)
        #expect(schedule.nextPause(after: .throttled, previous: capped)?.duration == 3600)
    }

    @Test("K34, K40: throttle after a failure starts from 200")
    func throttleAfterFailure() {
        let eighty = PushDeliveryConfirmationPause(answer: .failed, duration: 80)
        let capped = PushDeliveryConfirmationPause(answer: .failed, duration: 3600)
        #expect(schedule.nextPause(after: .throttled, previous: eighty)?.duration == 200)
        #expect(schedule.nextPause(after: .throttled, previous: capped)?.duration == 200)
    }

    @Test("K33, K41: failure after a throttle starts from 10")
    func failureAfterThrottle() {
        let throttle = PushDeliveryConfirmationPause(answer: .throttled, duration: 200)
        #expect(schedule.nextPause(after: .failed, previous: throttle)?.duration == 10)
    }

    @Test("K39: alternating answers start over each time")
    func alternating() {
        #expect(durations(for: [.throttled, .failed, .throttled]) == [200, 10, 200])
    }

    @Test("K42: a throttle series starts over after a capped failure series")
    func throttleAfterCappedFailures() {
        let answers = [PushDeliveryConfirmationAnswer](repeating: .failed, count: 10) + [.throttled, .throttled]
        let result = durations(for: answers)
        #expect(Array(result.suffix(3)) == [3600, 200, 400])
    }

    @Test("K12: delivered ends the series")
    func deliveredEndsSeries() {
        for previous in [PushDeliveryConfirmationAnswer.failed, .throttled] {
            let pause = PushDeliveryConfirmationPause(answer: previous, duration: 40)
            #expect(schedule.nextPause(after: .delivered, previous: pause) == nil)
        }
        #expect(schedule.nextPause(after: .delivered, previous: nil) == nil)
    }

    @Test("K50: rejected ends the series")
    func rejectedEndsSeries() {
        #expect(durations(for: [.failed, .rejected, .failed]) == [10, nil, 10])
        let first = schedule.nextPause(after: .failed, previous: nil)
        #expect(schedule.nextPause(after: .failed, previous: first)?.duration == 20)
    }

    @Test("wait applies jitter bounds", arguments: [
        (10.0, 7.5, 12.5),
        (200.0, 150.0, 250.0)
    ])
    func waitJitter(duration: TimeInterval, lower: TimeInterval, upper: TimeInterval) {
        let pause = PushDeliveryConfirmationPause(answer: .failed, duration: duration)
        let low = PushDeliveryConfirmationSchedule(random: \.lowerBound)
        let high = PushDeliveryConfirmationSchedule(random: \.upperBound)
        #expect(low.wait(for: pause) == lower)
        #expect(high.wait(for: pause) == upper)
    }
}
