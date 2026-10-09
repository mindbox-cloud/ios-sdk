//
//  EmbeddedBlockPlaceRegistering.swift
//  Mindbox
//
//  Created by Sergei Semko on 09.10.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

struct EmbeddedBlockPlaceAnswer {

    let resolution: EmbeddedBlockResolution

    /// How long the selection worked on it, the wait for a config included.
    let processingDuration: TimeInterval

    /// The session whose config the answer was computed from: an answer of an earlier session never
    /// accounts a show in a later one.
    let sessionEpoch: Int

    /// Only an operation asked — no config, session or appearance came with it: an answer of nothing
    /// applies at once, even under the user's eyes.
    let isOperationTriggered: Bool

    /// A new session's answer no block showed the place for, when asked or when it landed: its slot and its show's
    /// clock wait for a block back on screen.
    let isAskedOffScreen: Bool

    /// The new session's re-ask: landing while no block shows the place, it waits for one like an answer asked off
    /// screen, in sync with Android.
    let isNewSessionAsk: Bool

    func with(_ resolution: EmbeddedBlockResolution) -> EmbeddedBlockPlaceAnswer {
        copy(resolution: resolution)
    }

    func shownFromNow() -> EmbeddedBlockPlaceAnswer {
        copy(processingDuration: 0)
    }

    func landedOffScreen() -> EmbeddedBlockPlaceAnswer {
        copy(isAskedOffScreen: true)
    }

    private func copy(resolution: EmbeddedBlockResolution? = nil,
                      processingDuration: TimeInterval? = nil,
                      isAskedOffScreen: Bool? = nil) -> EmbeddedBlockPlaceAnswer {
        EmbeddedBlockPlaceAnswer(resolution: resolution ?? self.resolution,
                                 processingDuration: processingDuration ?? self.processingDuration,
                                 sessionEpoch: sessionEpoch,
                                 isOperationTriggered: isOperationTriggered,
                                 isAskedOffScreen: isAskedOffScreen ?? self.isAskedOffScreen,
                                 isNewSessionAsk: isNewSessionAsk)
    }
}

protocol EmbeddedBlockPlaceHandling: AnyObject {

    var isActive: Bool { get }

    /// The place's fresh answer, on the main thread.
    func apply(_ answer: EmbeddedBlockPlaceAnswer)

    /// The place's answer is known and held back by its `delayTime`: content is coming, the SDK is not silent.
    func contentIsDelayed()

    /// The place's content is kept until the return's session check ends: the SDK is not silent.
    func contentIsKept()

    /// The content kept for the place was handled: delivered, delayed or dropped.
    func keptContentIsReleased()

    /// Loading or showing, on screen or paused off it: the block still owes the place a show or a give-up.
    var holdsAnAttempt: Bool { get }
}

/// Main-thread confined, and every entry point hops there itself: a block's `init` and the container's
/// `deinit` are not promised the main thread by UIKit.
protocol EmbeddedBlockPlaceRegistering: AnyObject {

    func register(_ block: EmbeddedBlockPlaceHandling, place: String)

    func blockAppeared(_ place: String)

    func blockAttemptEnded(_ place: String)

    /// Read on the main thread, where the blocks live.
    func keepsContent(for place: String) -> Bool

    /// Content asked off screen takes its slot here, or turns empty, and is timed from now; `nil` once its session has ended. On main.
    func bringOnScreen(_ answer: EmbeddedBlockPlaceAnswer, at place: String) -> EmbeddedBlockPlaceAnswer?
}
