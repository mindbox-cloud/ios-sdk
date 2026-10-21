//
//  MindboxEmbeddedBlockViewDelegate.swift
//  Mindbox
//
//  Created by vailence on 03.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

/// Receives the outcomes of a ``MindboxEmbeddedBlockView``.
///
/// Calls arrive on the main thread once the block shows the outcome at its new height. The outcome can
/// change during the block's life, so each method can be called more than once. Every method has an
/// empty default implementation.
public protocol MindboxEmbeddedBlockViewDelegate: AnyObject {

    /// The content is shown.
    func mindboxEmbeddedBlockViewDidLoad(_ blockView: MindboxEmbeddedBlockView)

    /// The place has nothing to show; the block collapses.
    func mindboxEmbeddedBlockViewDidBecomeEmpty(_ blockView: MindboxEmbeddedBlockView)

    /// The block failed; it collapses or shows ``MindboxEmbeddedBlockView/errorView``.
    func mindboxEmbeddedBlockViewDidFail(_ blockView: MindboxEmbeddedBlockView,
                                         reason: MindboxEmbeddedBlockFailReason)
}

public extension MindboxEmbeddedBlockViewDelegate {

    func mindboxEmbeddedBlockViewDidLoad(_ blockView: MindboxEmbeddedBlockView) {}

    func mindboxEmbeddedBlockViewDidBecomeEmpty(_ blockView: MindboxEmbeddedBlockView) {}

    func mindboxEmbeddedBlockViewDidFail(_ blockView: MindboxEmbeddedBlockView,
                                         reason: MindboxEmbeddedBlockFailReason) {}
}
