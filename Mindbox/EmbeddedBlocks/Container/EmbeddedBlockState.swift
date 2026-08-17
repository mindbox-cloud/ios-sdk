//
//  EmbeddedBlockState.swift
//  Mindbox
//
//  Created by vailence on 03.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

/// The container's own view of the block content.
///
/// Deliberately internal: the host app only learns whether the block ended up shown or not,
/// never the intermediate progress, so the SDK stays free to change the flow later.
enum EmbeddedBlockState: Equatable {

    /// The content has not resolved yet.
    case loading

    /// The content is renderable.
    case ready

    /// The content failed to resolve — a load error, a timeout or broken content.
    case failed

    /// There is genuinely nothing to show — for instance, the block is disabled in the admin
    /// panel. Not a failure.
    case empty
}
