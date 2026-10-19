//
//  MindboxEmbeddedBlockAppearance.swift
//  Mindbox
//
//  Created by vailence on 18.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

/// How the block occupies its place right now, for a wrapper that lays the block out itself instead of
/// relying on `intrinsicContentSize`, such as ``MindboxEmbeddedBlock``.
///
/// The wrapper draws what the case says and sizes the block to match; the container decides which case
/// applies. Available only through `@_spi(Internal) import Mindbox`; host apps observe outcomes through
/// ``MindboxEmbeddedBlockViewDelegate``.
@_spi(Internal)
public enum MindboxEmbeddedBlockAppearance: Sendable {

    /// The block is loading and takes its height. A wrapper with a placeholder of its own draws it;
    /// otherwise the container already shows its shimmer.
    case placeholder

    /// The content is shown; the wrapper draws nothing over it.
    case content

    /// The block failed and has an error view: the wrapper draws its error screen. Never used for an
    /// empty place.
    case error

    /// The block takes no space: it waits hidden for content, it failed and shows no error screen, or
    /// the place has nothing to show. The wrapper gives the space back to the layout.
    case collapsed
}
