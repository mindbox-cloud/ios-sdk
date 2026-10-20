//
//  MindboxEmbeddedBlockViewDelegate.swift
//  Mindbox
//
//  Created by vailence on 03.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

/// Receives the outcome of a ``MindboxEmbeddedBlockView``: the content is shown, the place has nothing
/// to show, or the block failed.
///
/// Calls arrive on the main thread, when the block already shows the outcome and its
/// `intrinsicContentSize` reports the new height.
///
/// Only a change of outcome is reported: a delegate that stays assigned never receives the same
/// outcome twice in a row, and a failure that follows a failure is not reported even when its reason
/// differs. The outcome can change during the block's life, for example from shown content to empty
/// and back, so each method can be called more than once. Every method has an empty default
/// implementation and passes the view that called it, to tell several blocks apart.
public protocol MindboxEmbeddedBlockViewDelegate: AnyObject {

    /// The content is shown, and a block that was collapsed takes its height.
    func mindboxEmbeddedBlockViewDidLoad(_ blockView: MindboxEmbeddedBlockView)

    /// There is nothing to show at the place: no campaign whose targeting and A/B group match, a show
    /// limit is reached, or the page rendered nothing. The block collapses to zero height;
    /// ``MindboxEmbeddedBlockView/errorView`` does not apply.
    func mindboxEmbeddedBlockViewDidBecomeEmpty(_ blockView: MindboxEmbeddedBlockView)

    /// The block failed; `reason` says why, for logs and analytics. The block collapses to zero height,
    /// or keeps its height and shows ``MindboxEmbeddedBlockView/errorView`` when one is set and the
    /// block was taking its height.
    func mindboxEmbeddedBlockViewDidFail(_ blockView: MindboxEmbeddedBlockView,
                                         reason: MindboxEmbeddedBlockFailReason)
}

public extension MindboxEmbeddedBlockViewDelegate {

    func mindboxEmbeddedBlockViewDidLoad(_ blockView: MindboxEmbeddedBlockView) {}

    func mindboxEmbeddedBlockViewDidBecomeEmpty(_ blockView: MindboxEmbeddedBlockView) {}

    func mindboxEmbeddedBlockViewDidFail(_ blockView: MindboxEmbeddedBlockView,
                                         reason: MindboxEmbeddedBlockFailReason) {}
}
