//
//  EmbeddedBlockPageShow.swift
//  Mindbox
//
//  Created by Sergei Semko on 08.10.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

struct EmbeddedBlockPageShow {

    private(set) var confirmedEpoch: Int

    private var accountedEpoch: Int?

    private var isSessionClockRunning = false

    private(set) var isRefreshDue = false

    private var isAwaitingRefreshRender = false

    private(set) var isRenewingSession = false

    let isRebuildOfALostPage: Bool

    private(set) var processingDuration: TimeInterval

    private var stopwatch: ForegroundStopwatch

    private var renderedElapsed: TimeInterval?

    private let makeStopwatch: () -> ForegroundStopwatch

    init(builtFor sessionEpoch: Int,
         processingDuration: TimeInterval,
         isRebuildOfALostPage: Bool,
         makeStopwatch: @escaping () -> ForegroundStopwatch) {
        self.confirmedEpoch = sessionEpoch
        self.processingDuration = processingDuration
        self.isRebuildOfALostPage = isRebuildOfALostPage
        self.makeStopwatch = makeStopwatch
        self.stopwatch = makeStopwatch()
    }

    mutating func confirm(_ answer: EmbeddedBlockPlaceAnswer) {
        guard answer.sessionEpoch > confirmedEpoch else { return }

        confirmedEpoch = answer.sessionEpoch
        processingDuration = answer.processingDuration
        stopwatch = makeStopwatch()
        renderedElapsed = nil
        isRefreshDue = true
        isSessionClockRunning = true
        isRenewingSession = true
    }

    mutating func suspend() {
        stopwatch.suspend()
    }

    mutating func resume() {
        stopwatch.resume()
    }

    var processingDurationOfARebuild: TimeInterval {
        isSessionClockRunning ? processingDuration + stopwatch.elapsed : processingDuration
    }

    var processingDurationOfALostPage: TimeInterval {
        processingDuration + stopwatch.elapsed
    }

    mutating func requireRefresh() {
        isRefreshDue = true
    }

    mutating func refreshSent() {
        isRefreshDue = false
        isAwaitingRefreshRender = true
    }

    mutating func pageRendered() {
        renderedElapsed = processingDuration + stopwatch.elapsed
        isAwaitingRefreshRender = false
        if !isRefreshDue { isRenewingSession = false }
    }

    mutating func takeDueShow() -> (sessionEpoch: Int, timeToDisplay: TimeInterval)? {
        guard !isRefreshDue, !isAwaitingRefreshRender, accountedEpoch != confirmedEpoch else { return nil }

        accountedEpoch = confirmedEpoch
        isSessionClockRunning = false
        let timeToDisplay = renderedElapsed ?? processingDuration + stopwatch.elapsed
        stopwatch.stop()
        return (confirmedEpoch, timeToDisplay)
    }
}
