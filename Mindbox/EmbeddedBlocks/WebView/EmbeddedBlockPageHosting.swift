//
//  EmbeddedBlockPageHosting.swift
//  Mindbox
//
//  Created by vailence on 03.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit

/// The embedded block page — everything the provider needs from the web view.
///
/// The single seam inside the block and the single place where WebKit lives: this is what lets the
/// translation of page messages into block states be tested without a real web view and without
/// the network.
protocol EmbeddedBlockPageHosting: AnyObject {

    /// The page view. The provider hands it to the container as the block content.
    var view: UIView { get }

    /// Messages from the page. Delivered on the main thread.
    var onMessage: ((EmbeddedBlockPageMessage) -> Void)? { get set }

    /// The page failed to load — connection, domain, a cancelled navigation. That is all navigation
    /// reports: whether the page is ready is decided by the page itself with its `ready`.
    /// Delivered on the main thread.
    var onLoadFailure: (() -> Void)? { get set }

    /// The document has loaded. That does not mean the block is ready — the page may be empty or
    /// broken — so the regular path ignores this signal: the only listener is the debug readiness
    /// override for pages without the web contract. Delivered on the main thread.
    var onLoadFinish: (() -> Void)? { get set }

    func load()

    /// Stops the loading. The page and its bridge stay in place: the block may come back into the
    /// window, and then the already rendered page is shown again without a reload.
    func cancel()
}
