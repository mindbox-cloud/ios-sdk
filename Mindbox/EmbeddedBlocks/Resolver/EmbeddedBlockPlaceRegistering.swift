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

    func with(_ resolution: EmbeddedBlockResolution) -> EmbeddedBlockPlaceAnswer {
        copy(resolution: resolution)
    }

    func with(processingDuration: TimeInterval) -> EmbeddedBlockPlaceAnswer {
        copy(processingDuration: processingDuration)
    }

    func replacing(_ waiting: EmbeddedBlockPlaceAnswer) -> EmbeddedBlockPlaceAnswer {
        copy(processingDuration: waiting.processingDuration)
    }

    private func copy(resolution: EmbeddedBlockResolution? = nil,
                      processingDuration: TimeInterval? = nil) -> EmbeddedBlockPlaceAnswer {
        EmbeddedBlockPlaceAnswer(resolution: resolution ?? self.resolution,
                                 processingDuration: processingDuration ?? self.processingDuration,
                                 sessionEpoch: sessionEpoch,
                                 isOperationTriggered: isOperationTriggered)
    }
}

protocol EmbeddedBlockPlaceHandling: AnyObject {

    var isActive: Bool { get }

    var isStartPending: Bool { get }

    func apply(_ answer: EmbeddedBlockPlaceAnswer)

    func contentIsDelayed()

    func contentIsKept()

    func keptContentIsReleased()

    var holdsAnAttempt: Bool { get }
}

// Main thread only; keepsContent(for:) and bringOnScreen(_:at:) answer synchronously.
protocol EmbeddedBlockPlaceRegistering: AnyObject {

    func register(_ block: EmbeddedBlockPlaceHandling, place: String)

    func blockAppeared(_ place: String)

    func blockAttemptEnded(_ place: String)

    func giveSlotBack(_ unseen: EmbeddedBlockPlaceAnswer, at place: String)

    func keepsContent(for place: String) -> Bool

    func bringOnScreen(_ answer: EmbeddedBlockPlaceAnswer, at place: String) -> EmbeddedBlockPlaceAnswer?
}
