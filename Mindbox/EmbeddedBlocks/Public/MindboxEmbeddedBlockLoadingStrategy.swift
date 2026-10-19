//
//  MindboxEmbeddedBlockLoadingStrategy.swift
//  Mindbox
//
//  Created by vailence on 24.09.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

/// What a new block shows while it waits for its first outcome: a placeholder that takes the block's
/// height, or nothing. Set when the block is created; the default is
/// ``MindboxEmbeddedBlockLoadingStrategy/automatic``.
public enum MindboxEmbeddedBlockLoadingStrategy: Sendable {

    /// Like ``MindboxEmbeddedBlockLoadingStrategy/placeholder`` if this place has shown content on this
    /// device, in this or an earlier app launch, and has not come out empty since; otherwise like
    /// ``MindboxEmbeddedBlockLoadingStrategy/hidden``.
    case automatic

    /// A placeholder until the block's first outcome: the host's own
    /// (``MindboxEmbeddedBlockView/placeholderView`` or ``MindboxEmbeddedBlock/placeholder(_:)``) or the
    /// SDK's shimmer.
    case placeholder

    /// Zero height until the block has shown content: no placeholder, and no error view on a failure,
    /// which is still reported to the delegate or `onFail`.
    case hidden
}
