//
//  MindboxEmbeddedBlockLoadingStrategy.swift
//  Mindbox
//
//  Created by vailence on 24.09.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

/// What a block shows while it loads, set when the block is created.
public enum MindboxEmbeddedBlockLoadingStrategy: Sendable {

    /// ``MindboxEmbeddedBlockLoadingStrategy/placeholder`` if the place has shown content on this device
    /// and has not come out empty since, otherwise ``MindboxEmbeddedBlockLoadingStrategy/hidden``.
    case automatic

    /// A placeholder at the block's height: the host's own or the SDK's shimmer.
    case placeholder

    /// Zero height until the content is shown.
    case hidden
}
