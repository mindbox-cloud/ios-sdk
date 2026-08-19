//
//  EmbeddedBlockPresentation.swift
//  Mindbox
//
//  Created by vailence on 10.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import CoreGraphics

/// What the container shows right now — a snapshot for the SwiftUI wrapper, which draws the host's
/// placeholder/error views itself: handed into the container they would fall out of the SwiftUI
/// tree and lose their environment.
struct EmbeddedBlockPresentation: Equatable {

    enum Layer {
        case placeholder
        case content
        case errorView

        /// Collapsed: a failure without an error screen, or an empty block.
        case nothing
    }

    let layer: Layer
    let height: CGFloat
}
