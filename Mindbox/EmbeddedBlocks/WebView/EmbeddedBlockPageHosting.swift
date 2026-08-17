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
/// The single seam inside the block and the single place where WebKit lives: this is what lets
/// the translation of page reports into block states be tested without a real web view and
/// without the network.
protocol EmbeddedBlockPageHosting: AnyObject {

    /// The page view. The provider hands it to the container as the block content.
    var view: UIView { get }

    /// The page rendered `count` pieces of content. Fires once per load. A count of `0` means
    /// the page is alive and correct and has nothing to show. Delivered on the main thread.
    var onContentRendered: ((Int) -> Void)? { get set }

    /// The page failed to load — connection, domain, a bad address. That is all navigation
    /// reports: whether there is anything to show is decided by the page itself.
    /// Delivered on the main thread.
    var onLoadFailure: (() -> Void)? { get set }

    /// The document has loaded. That does not mean the block has content — the page may be empty
    /// or broken — so the regular path ignores this signal: the only listener is the debug
    /// readiness override for pages without the web contract. Delivered on the main thread.
    var onLoadFinish: (() -> Void)? { get set }

    /// Whether the block is on screen for the user. The provider keeps it current; the page's
    /// bridge reads it before doing anything on the user's behalf, such as opening a link.
    var isUserPresent: Bool { get set }

    func load()

    /// Starts the page over. Used when a block that already resolved is asked to load again.
    func reload()

    /// Stops the loading. The page and its bridge stay in place: the block may come back into the
    /// window, and then the already rendered page is shown again without a reload.
    func cancel()
}
