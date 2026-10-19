//
//  MindboxEmbeddedBlockLoadingStrategy.swift
//  Mindbox
//
//  Created by vailence on 24.09.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

/// What the block shows while its content loads: a placeholder that takes the block's
/// height, or nothing. Set when the block is created; the default is
/// ``MindboxEmbeddedBlockLoadingStrategy/automatic``.
public enum MindboxEmbeddedBlockLoadingStrategy: Sendable {

    /// Hidden until content has been shown at this place on this device; a placeholder from then on.
    ///
    /// The SDK remembers this per place system name across app launches. A place that turns out to
    /// have nothing to show is forgotten, so the next block created there starts hidden again; a
    /// failure keeps the record.
    case automatic

    /// A placeholder until content is shown: the host's own (``MindboxEmbeddedBlockView/placeholderView``
    /// or ``MindboxEmbeddedBlock/placeholder(_:)``) or the SDK's shimmer.
    case placeholder

    /// Zero height until the block has shown content: no placeholder, and no error view on a failure,
    /// which is still reported to the delegate or `onFail`. Once it has shown content, the block shows
    /// a placeholder while new content loads.
    case hidden
}
