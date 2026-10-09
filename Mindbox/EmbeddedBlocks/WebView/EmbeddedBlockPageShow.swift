//
//  EmbeddedBlockPageShow.swift
//  Mindbox
//
//  Created by Sergei Semko on 08.10.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

/// When one page's `Inapp.Show` is due, and the clock its `timeToDisplay` runs on. Main thread only, like
/// the provider that owns it.
struct EmbeddedBlockPageShow {

    /// The newest session whose answer named this page's content.
    private(set) var confirmedEpoch: Int

    private var accountedEpoch: Int?

    /// A later session restarted the clock, and its show is still owed.
    private var isSessionClockRunning = false

    /// The page is owed its data but cannot take it yet: it has not drawn, or nobody is looking.
    private(set) var isRefreshDue = false

    private var isAwaitingRefreshRender = false

    /// The selection's part of `timeToDisplay`; the page's part runs on `stopwatch`.
    private(set) var processingDuration: TimeInterval

    private var stopwatch: ForegroundStopwatch

    /// `timeToDisplay` frozen at the moment the page drew: a show sent on a later return reports the
    /// render, not the time nobody was looking.
    private var renderedElapsed: TimeInterval?

    private let makeStopwatch: () -> ForegroundStopwatch

    init(builtFor sessionEpoch: Int,
         processingDuration: TimeInterval,
         makeStopwatch: @escaping () -> ForegroundStopwatch) {
        self.confirmedEpoch = sessionEpoch
        self.processingDuration = processingDuration
        self.makeStopwatch = makeStopwatch
        self.stopwatch = makeStopwatch()
    }

    /// A later session is a cold start for the page, whatever asked: the clock restarts from that answer's
    /// selection, and the page is owed its data, equal data included.
    mutating func confirm(_ answer: EmbeddedBlockPlaceAnswer) {
        guard answer.sessionEpoch > confirmedEpoch else { return }

        confirmedEpoch = answer.sessionEpoch
        processingDuration = answer.processingDuration
        stopwatch = makeStopwatch()
        renderedElapsed = nil
        isRefreshDue = true
        isSessionClockRunning = true
    }

    /// The selection's part for a page rebuilt in this one's place: a later session's show still counts from
    /// that session's selection; within a session the rebuild counts from the stored selection.
    var processingDurationOfARebuild: TimeInterval {
        isSessionClockRunning ? processingDuration + stopwatch.elapsed : processingDuration
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
    }

    /// The show this page owes, once per confirming session: `nil` while the page is still owed its
    /// data, or has not drawn what it was handed.
    mutating func takeDueShow() -> (sessionEpoch: Int, timeToDisplay: TimeInterval)? {
        guard !isRefreshDue, !isAwaitingRefreshRender, accountedEpoch != confirmedEpoch else { return nil }

        accountedEpoch = confirmedEpoch
        isSessionClockRunning = false
        let timeToDisplay = renderedElapsed ?? processingDuration + stopwatch.elapsed
        stopwatch.stop()
        return (confirmedEpoch, timeToDisplay)
    }
}
