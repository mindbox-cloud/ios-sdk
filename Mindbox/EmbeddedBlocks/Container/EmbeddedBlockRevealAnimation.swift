//
//  EmbeddedBlockRevealAnimation.swift
//  Mindbox
//
//  Created by vailence on 24.09.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit

/// The SDK's own reveal of the block content — a fade of the content and, for a block that started
/// hidden, the growth of its height — with its two seams: the animation call and the accessibility
/// setting that turns animation off. Nothing about the curve or the timing is open to the host: a host
/// that wants its own puts the block in a container of its own and animates that in `didLoad`.
struct EmbeddedBlockRevealAnimation {

    typealias Run = (_ duration: TimeInterval, _ animations: @escaping () -> Void, _ completion: @escaping () -> Void) -> Void

    let duration: TimeInterval

    let run: Run

    let isReduceMotionEnabled: () -> Bool

    init(duration: TimeInterval = Constants.EmbeddedBlock.revealAnimationDuration,
         run: @escaping Run = { duration, animations, completion in
             UIView.animate(withDuration: duration, animations: animations, completion: { _ in completion() })
         },
         isReduceMotionEnabled: @escaping () -> Bool = { UIAccessibility.isReduceMotionEnabled }) {
        self.duration = duration
        self.run = run
        self.isReduceMotionEnabled = isReduceMotionEnabled
    }
}
