//
//  EmbeddedBlockRevealAnimation.swift
//  Mindbox
//
//  Created by vailence on 24.09.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit

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
