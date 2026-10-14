//
//  EmbeddedBlockPlaceRegistering.swift
//  Mindbox
//
//  Created by Sergei Semko on 09.10.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

protocol EmbeddedBlockPlaceHandling: AnyObject {

    var isActive: Bool { get }

    /// The place's fresh answer, on the main thread, with how long the selection worked on it.
    func apply(_ resolution: EmbeddedBlockResolution, processingDuration: TimeInterval)

    /// The place's answer is known and held back by its `delayTime`: content is coming, the SDK is not silent.
    func contentIsDelayed()

    /// Loading or showing, on screen or paused off it: the block still owes the place a show or a give-up.
    var holdsAnAttempt: Bool { get }
}

/// Main-thread confined, and every entry point hops there itself: a block's `init` and the container's
/// `deinit` are not promised the main thread by UIKit.
protocol EmbeddedBlockPlaceRegistering: AnyObject {

    func register(_ block: EmbeddedBlockPlaceHandling, place: String)

    func blockAppeared(_ place: String)

    func blockAttemptEnded(_ place: String)
}
