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
/// The block resolves into one of three outcomes: it is shown, there is nothing to show, or it
/// failed. Intermediate states like "started loading" stay internal.
///
/// Every method has an empty default implementation, so only the interesting ones have to be
/// written. Calls always arrive on the main thread. Every method hands back the view that fired
/// it — with several blocks on screen, compare it against your own references (or give each block
/// its own delegate) to tell them apart.
public protocol MindboxEmbeddedBlockViewDelegate: AnyObject {

    /// The block content is shown: the container has taken its own height and is visible.
    func mindboxEmbeddedBlockViewDidLoad(_ blockView: MindboxEmbeddedBlockView)

    /// There is nothing to show at the place: no campaign behind its place system name, the
    /// targeting or the A/B group did not match, the show budget is spent, or the page rendered
    /// nothing. The container collapses to zero height; `errorView` does not apply. No reason is
    /// given — which of these it was is the SDK's business.
    func mindboxEmbeddedBlockViewDidBecomeEmpty(_ blockView: MindboxEmbeddedBlockView)

    /// The block could not be shown: the SDK had no config or never answered, the page could not be
    /// loaded, the content is malformed or the SDK hit an internal error. The container collapses to zero height, or keeps
    /// its height and shows `errorView` when one is set. `reason` says why, for logs and analytics —
    /// match it with a `default`, a later SDK may add reasons.
    func mindboxEmbeddedBlockViewDidFail(_ blockView: MindboxEmbeddedBlockView,
                                         reason: MindboxEmbeddedBlockFailReason)
}

public extension MindboxEmbeddedBlockViewDelegate {

    func mindboxEmbeddedBlockViewDidLoad(_ blockView: MindboxEmbeddedBlockView) {}

    func mindboxEmbeddedBlockViewDidBecomeEmpty(_ blockView: MindboxEmbeddedBlockView) {}

    func mindboxEmbeddedBlockViewDidFail(_ blockView: MindboxEmbeddedBlockView,
                                         reason: MindboxEmbeddedBlockFailReason) {}
}
