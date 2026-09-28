//
//  EmbeddedBlockState.swift
//  Mindbox
//
//  Created by vailence on 03.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

/// The container's own view of the block content.
///
/// Deliberately internal: the host app hears only the outcomes — shown, empty or failed with a
/// reason — never the intermediate progress, so the SDK stays free to change the flow later.
enum EmbeddedBlockState: Equatable {

    /// The content has not resolved yet.
    case loading

    /// The content is renderable.
    case ready

    case failed(MindboxEmbeddedBlockFailReason)

    case empty

    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }
}
