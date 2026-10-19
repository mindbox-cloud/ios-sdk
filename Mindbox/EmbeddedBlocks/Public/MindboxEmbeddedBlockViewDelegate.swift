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
/// Calls arrive on the main thread. Only a change of outcome is reported: the same outcome never
/// arrives twice in a row, so a block that replaces its content and shows it again does not call
/// ``MindboxEmbeddedBlockViewDelegate/mindboxEmbeddedBlockViewDidLoad(_:)`` again. A delegate
/// assigned after the outcome receives the current one. Every method has an empty default
/// implementation and passes the view that called it, to tell several blocks apart.
public protocol MindboxEmbeddedBlockViewDelegate: AnyObject {

    /// The content is shown. A block that waited hidden takes its height at this point, growing from 0,
    /// so a table or collection view that sizes the row itself should remeasure it here, as on empty
    /// and failure.
    func mindboxEmbeddedBlockViewDidLoad(_ blockView: MindboxEmbeddedBlockView)

    /// There is nothing to show at the place: no campaign whose targeting and A/B group match, a show
    /// limit is reached, or the page rendered nothing. The block collapses to zero height;
    /// ``MindboxEmbeddedBlockView/errorView`` does not apply.
    func mindboxEmbeddedBlockViewDidBecomeEmpty(_ blockView: MindboxEmbeddedBlockView)

    /// The block could not be shown; `reason` says why, for logs and analytics. The block collapses to
    /// zero height, or keeps its height and shows ``MindboxEmbeddedBlockView/errorView`` when one is set
    /// and the block was taking its space.
    func mindboxEmbeddedBlockViewDidFail(_ blockView: MindboxEmbeddedBlockView,
                                         reason: MindboxEmbeddedBlockFailReason)
}

public extension MindboxEmbeddedBlockViewDelegate {

    func mindboxEmbeddedBlockViewDidLoad(_ blockView: MindboxEmbeddedBlockView) {}

    func mindboxEmbeddedBlockViewDidBecomeEmpty(_ blockView: MindboxEmbeddedBlockView) {}

    func mindboxEmbeddedBlockViewDidFail(_ blockView: MindboxEmbeddedBlockView,
                                         reason: MindboxEmbeddedBlockFailReason) {}
}
