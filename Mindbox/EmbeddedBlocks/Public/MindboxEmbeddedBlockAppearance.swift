//
//  MindboxEmbeddedBlockAppearance.swift
//  Mindbox
//
//  Created by vailence on 18.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

/// How the block occupies its place right now, for a wrapper that lays the block out itself, such as
/// ``MindboxEmbeddedBlock``; host apps observe outcomes through ``MindboxEmbeddedBlockViewDelegate``.
@_spi(Internal)
public enum MindboxEmbeddedBlockAppearance: Sendable {

    /// The block is loading at its height and shows its ``MindboxEmbeddedBlockView/placeholderView``,
    /// or the SDK's shimmer while that is `nil`; a wrapper with a placeholder of its own draws it on top.
    case placeholder

    /// The content is shown at the block's height; the wrapper draws nothing over it.
    case content

    /// The block failed and shows its ``MindboxEmbeddedBlockView/errorView`` at its height, so this comes
    /// only while that view is set; the wrapper draws its own error view on top.
    case error

    /// The block takes no space; the wrapper gives the space back to the layout.
    case collapsed
}
