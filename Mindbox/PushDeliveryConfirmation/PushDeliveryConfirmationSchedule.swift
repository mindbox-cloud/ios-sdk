//
//  PushDeliveryConfirmationSchedule.swift
//  Mindbox
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
#if SWIFT_PACKAGE
@_spi(Internal)
import MindboxShared
#endif

struct PushDeliveryConfirmationPause: Equatable, Sendable {
    let answer: PushDeliveryConfirmationAnswer
    let duration: TimeInterval
}

struct PushDeliveryConfirmationSchedule: Sendable {
    static let firstFailurePause: TimeInterval = 10
    static let firstThrottlePause: TimeInterval = 200
    static let maxPause: TimeInterval = 3600
    static let maxWait: TimeInterval = 4500

    private let random: @Sendable (ClosedRange<Double>) -> Double

    init(random: @escaping @Sendable (ClosedRange<Double>) -> Double = { Double.random(in: $0) }) {
        self.random = random
    }

    func nextPause(
        after answer: PushDeliveryConfirmationAnswer,
        previous: PushDeliveryConfirmationPause?
    ) -> PushDeliveryConfirmationPause? {
        let first: TimeInterval
        switch answer {
        case .failed:
            first = Self.firstFailurePause
        case .throttled:
            first = Self.firstThrottlePause
        case .delivered, .rejected:
            return nil
        }

        guard let previous, previous.answer == answer else {
            return PushDeliveryConfirmationPause(answer: answer, duration: first)
        }
        return PushDeliveryConfirmationPause(answer: answer, duration: min(previous.duration * 2, Self.maxPause))
    }

    func wait(for pause: PushDeliveryConfirmationPause) -> TimeInterval {
        pause.duration * random(0.75...1.25)
    }
}
