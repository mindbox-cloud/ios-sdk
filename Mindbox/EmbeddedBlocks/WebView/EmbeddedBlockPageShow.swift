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

    /// The selection's part of `timeToDisplay`; the page's part runs on `stopwatch`.
    private(set) var processingDuration: TimeInterval

    private var stopwatch: ForegroundStopwatch

    /// `timeToDisplay` frozen at the moment the page drew: a show sent on a later return reports the
    /// render, not the time nobody was looking.
    private var renderedElapsed: TimeInterval?

    init(builtFor sessionEpoch: Int,
         processingDuration: TimeInterval,
         makeStopwatch: @escaping () -> ForegroundStopwatch) {
        self.confirmedEpoch = sessionEpoch
        self.processingDuration = processingDuration
        self.stopwatch = makeStopwatch()
    }

    mutating func suspend() {
        stopwatch.suspend()
    }

    mutating func resume() {
        stopwatch.resume()
    }

    mutating func pageRendered() {
        renderedElapsed = processingDuration + stopwatch.elapsed
    }

    mutating func takeDueShow() -> (sessionEpoch: Int, timeToDisplay: TimeInterval)? {
        guard accountedEpoch != confirmedEpoch else { return nil }

        accountedEpoch = confirmedEpoch
        let timeToDisplay = renderedElapsed ?? processingDuration + stopwatch.elapsed
        stopwatch.stop()
        return (confirmedEpoch, timeToDisplay)
    }
}
