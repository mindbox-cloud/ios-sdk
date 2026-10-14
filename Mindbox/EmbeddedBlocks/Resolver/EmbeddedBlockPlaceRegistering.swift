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

    let processingDuration: TimeInterval

    let sessionEpoch: Int

    let isOperationTriggered: Bool

    let isAskedOffScreen: Bool

    let isNewSessionAsk: Bool

    func with(_ resolution: EmbeddedBlockResolution) -> EmbeddedBlockPlaceAnswer {
        copy(resolution: resolution)
    }

    func with(processingDuration: TimeInterval) -> EmbeddedBlockPlaceAnswer {
        copy(processingDuration: processingDuration)
    }

    func landedOffScreen() -> EmbeddedBlockPlaceAnswer {
        copy(isAskedOffScreen: true)
    }

    func replacing(_ waiting: EmbeddedBlockPlaceAnswer) -> EmbeddedBlockPlaceAnswer {
        copy(processingDuration: waiting.processingDuration,
             isAskedOffScreen: isAskedOffScreen || waiting.isAskedOffScreen,
             isNewSessionAsk: isNewSessionAsk || waiting.isNewSessionAsk)
    }

    private func copy(resolution: EmbeddedBlockResolution? = nil,
                      processingDuration: TimeInterval? = nil,
                      isAskedOffScreen: Bool? = nil,
                      isNewSessionAsk: Bool? = nil) -> EmbeddedBlockPlaceAnswer {
        EmbeddedBlockPlaceAnswer(resolution: resolution ?? self.resolution,
                                 processingDuration: processingDuration ?? self.processingDuration,
                                 sessionEpoch: sessionEpoch,
                                 isOperationTriggered: isOperationTriggered,
                                 isAskedOffScreen: isAskedOffScreen ?? self.isAskedOffScreen,
                                 isNewSessionAsk: isNewSessionAsk ?? self.isNewSessionAsk)
    }
}

protocol EmbeddedBlockPlaceHandling: AnyObject {

    var isActive: Bool { get }

    var isStartPending: Bool { get }

    /// The place's fresh answer, on the main thread.
    func apply(_ answer: EmbeddedBlockPlaceAnswer)

    /// The place's answer is known and held back by its `delayTime`: content is coming, the SDK is not silent.
    func contentIsDelayed()

    func contentIsKept()

    func keptContentIsReleased()

    /// Loading or showing, on screen or paused off it: the block still owes the place a show or a give-up.
    var holdsAnAttempt: Bool { get }
}

/// Main-thread confined. The void entry points hop there themselves: a block's `init` and the container's `deinit` are not
/// promised the main thread by UIKit. `keepsContent(for:)` and `bringOnScreen(_:at:)` answer synchronously: call them on main.
protocol EmbeddedBlockPlaceRegistering: AnyObject {

    func register(_ block: EmbeddedBlockPlaceHandling, place: String)

    func blockAppeared(_ place: String)

    func blockAttemptEnded(_ place: String)

    func keepsContent(for place: String) -> Bool

    func bringOnScreen(_ answer: EmbeddedBlockPlaceAnswer, at place: String) -> EmbeddedBlockPlaceAnswer?
}
