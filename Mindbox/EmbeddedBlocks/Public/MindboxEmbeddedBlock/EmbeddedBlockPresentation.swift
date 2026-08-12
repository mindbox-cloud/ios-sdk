//
//  EmbeddedBlockPresentation.swift
//  Mindbox
//
//  Created by vailence on 10.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import CoreGraphics

/// What the container shows right now — a snapshot for the SwiftUI wrapper.
///
/// A UIKit host needs no such type: the container declares its height through `intrinsicContentSize`
/// and holds the right layer inside, both on its own. SwiftUI can do neither. The wrapper assigns
/// the representable's height, and the host's placeholder and error screen are SwiftUI views the
/// wrapper must draw too: a view handed to the container through a separate `UIHostingController`
/// falls out of the SwiftUI tree and loses its environment. So the wrapper needs not only the
/// size but the current layer too.
///
/// Deliberately internal, like `EmbeddedBlockState`: the host knows only the outcome, not how the
/// container arrived at it.
struct EmbeddedBlockPresentation: Equatable {

    /// The layer visible in the container.
    enum Layer {

        /// Loading is underway: the placeholder is shown — the host's or the SDK's default shimmer.
        case placeholder

        /// The block content is shown.
        case content

        /// The error screen the host explicitly opted into is shown.
        case errorView

        /// The block is collapsed: a failure without an error screen, or an empty block.
        case nothing
    }

    let layer: Layer

    /// The height the container occupies with this layer.
    let height: CGFloat
}
