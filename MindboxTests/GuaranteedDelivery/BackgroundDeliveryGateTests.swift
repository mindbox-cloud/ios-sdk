//
//  BackgroundDeliveryGateTests.swift
//  MindboxTests
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import Testing
@testable import Mindbox

@Suite("Background delivery gate")
struct BackgroundDeliveryGateTests {

    private final class Finishes: @unchecked Sendable {
        private let lock = NSLock()
        private var storage: [Bool] = []

        var values: [Bool] {
            lock.withLock { storage }
        }

        func append(_ value: Bool) {
            lock.withLock { storage.append(value) }
        }
    }

    private let finishes = Finishes()

    private func makeGate() -> BackgroundDeliveryGate {
        let finishes = finishes
        return BackgroundDeliveryGate { finishes.append($0) }
    }

    @Test("Only the event queue finished: the task is not completed")
    func eventsOnlyDoNotFinish() {
        let gate = makeGate()

        gate.eventsFinished(success: true)

        #expect(finishes.values.isEmpty)
    }

    @Test("Only the confirmation queue finished: the task is not completed")
    func confirmationsOnlyDoNotFinish() {
        let gate = makeGate()

        gate.confirmationsFinished()

        #expect(finishes.values.isEmpty)
    }

    @Test("Events then confirmations: finished once with the success of the event queue", arguments: [true, false])
    func eventsThenConfirmations(success: Bool) {
        let gate = makeGate()

        gate.eventsFinished(success: success)
        gate.confirmationsFinished()

        #expect(finishes.values == [success])
    }

    @Test("Confirmations then events: finished once with the success of the event queue", arguments: [true, false])
    func confirmationsThenEvents(success: Bool) {
        let gate = makeGate()

        gate.confirmationsFinished()
        gate.eventsFinished(success: success)

        #expect(finishes.values == [success])
    }

    @Test("A second signal of the event queue with another value changes nothing")
    func secondEventsSignalIgnored() {
        let gate = makeGate()

        gate.eventsFinished(success: true)
        gate.eventsFinished(success: false)
        gate.confirmationsFinished()
        gate.eventsFinished(success: false)
        gate.confirmationsFinished()

        #expect(finishes.values == [true])
    }

    @Test("finishNow(false) finishes at once and later signals do nothing")
    func finishNowFinishesAtOnce() {
        let gate = makeGate()

        gate.eventsFinished(success: true)
        gate.finishNow(success: false)
        gate.confirmationsFinished()
        gate.finishNow(success: true)
        gate.eventsFinished(success: true)

        #expect(finishes.values == [false])
    }

    @Test("finishNow before any signal finishes at once")
    func finishNowBeforeSignals() {
        let gate = makeGate()

        gate.finishNow(success: false)

        #expect(finishes.values == [false])

        gate.eventsFinished(success: true)
        gate.confirmationsFinished()

        #expect(finishes.values == [false])
    }

    @Test("K22: signals from many threads at once finish the task exactly once")
    func concurrentSignalsFinishOnce() async {
        for _ in 0..<200 {
            let finishes = Finishes()
            let gate = BackgroundDeliveryGate { finishes.append($0) }

            await withTaskGroup(of: Void.self) { group in
                group.addTask { gate.eventsFinished(success: true) }
                group.addTask { gate.confirmationsFinished() }
                group.addTask { gate.eventsFinished(success: true) }
                group.addTask { gate.confirmationsFinished() }
            }

            #expect(finishes.values == [true])
        }
    }

    @Test("K22: finishNow racing both signals finishes the task exactly once")
    func concurrentFinishNowFinishesOnce() async {
        for _ in 0..<200 {
            let finishes = Finishes()
            let gate = BackgroundDeliveryGate { finishes.append($0) }

            await withTaskGroup(of: Void.self) { group in
                group.addTask { gate.eventsFinished(success: true) }
                group.addTask { gate.confirmationsFinished() }
                group.addTask { gate.finishNow(success: false) }
            }

            #expect(finishes.values.count == 1)
        }
    }
}
