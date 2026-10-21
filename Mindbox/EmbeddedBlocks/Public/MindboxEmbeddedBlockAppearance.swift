//
//  MindboxEmbeddedBlockAppearance.swift
//  Mindbox
//
//  Created by vailence on 18.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

/// How the block occupies its place, for a wrapper that lays the block out itself.
@_spi(Internal)
public enum MindboxEmbeddedBlockAppearance: Sendable {

    /// A placeholder at the block's height.
    case placeholder

    /// The content at the block's height.
    case content

    /// The error view at the block's height.
    case error

    /// Zero height.
    case collapsed
}
