//
//  MindboxEmbeddedBlockViewDelegate.swift
//  Mindbox
//
//  Created by vailence on 03.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

/// The events a host app can observe on `MindboxEmbeddedBlockView`.
///
/// The block resolves into one of two outcomes: it is either shown or it is not. Intermediate
/// states like "started loading" stay internal.
///
/// Every method has an empty default implementation, so only the interesting ones have to be
/// written. Calls always arrive on the main thread. Every method hands back the view that fired
/// it — with several blocks on screen, compare it against your own references (or give each block
/// its own delegate) to tell them apart.
public protocol MindboxEmbeddedBlockViewDelegate: AnyObject {

    /// The block content is shown: the container has taken its own height and is visible.
    func mindboxEmbeddedBlockViewDidLoad(_ blockView: MindboxEmbeddedBlockView)

    /// The block cannot be shown. Covers failures — the load broke, timed out or the content is
    /// malformed — and also the empty block, one that has nothing behind its place system name. On a failure the
    /// container collapses to zero height, or keeps its height and shows `errorView` when one is
    /// set; an empty block always collapses, `errorView` does not apply to it.
    func mindboxEmbeddedBlockViewDidFail(_ blockView: MindboxEmbeddedBlockView)
}

public extension MindboxEmbeddedBlockViewDelegate {

    func mindboxEmbeddedBlockViewDidLoad(_ blockView: MindboxEmbeddedBlockView) {}

    func mindboxEmbeddedBlockViewDidFail(_ blockView: MindboxEmbeddedBlockView) {}
}
