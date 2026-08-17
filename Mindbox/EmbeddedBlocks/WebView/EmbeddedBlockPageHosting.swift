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
///
/// The bridge envelopes stay on the page's side of this line. The shared action handlers parse
/// requests and answer them; what crosses here is domain values only, so the provider decides
/// what a report means without ever seeing a `BridgeMessage`.
protocol EmbeddedBlockPageHosting: AnyObject {

    /// The page view. The provider hands it to the container as the block content.
    var view: UIView { get }

    /// The page rendered `count` pieces of content, once per load. At or below `0` means the
    /// page is alive and correct and has nothing to show. Delivered on the main thread.
    var onContentRendered: ((Int) -> Void)? { get set }

    /// The page reported content, but the report could not be read. The page was already
    /// refused; the block holds a show nobody can vouch for. Delivered on the main thread.
    var onUnreadableContentReport: (() -> Void)? { get set }

    /// The page asks which of these ids it may render. The answer goes back through `completion`
    /// — from wherever the selection finishes. Delivered on the main thread.
    var onFeedQuestion: (([String], @escaping ([String]) -> Void) -> Void)? { get set }

    /// The page asks to show an in-app by id, with the params that travel into its start
    /// payload untouched. Delivered on the main thread.
    var onShowInAppRequest: ((String, [String: JSONValue]) -> Void)? { get set }

    /// The page confirmed the `initDataUpdated` push — the provider is waiting on it.
    /// Delivered on the main thread.
    var onDataPushConfirmed: (() -> Void)? { get set }

    /// The page failed to load — the markup fetch or the navigation itself. Whether the block
    /// has anything to show, in contrast, is the page's own statement. Delivered on the main
    /// thread.
    var onLoadFailure: (() -> Void)? { get set }

    /// Whether the block is on screen for the user. The provider keeps it current; the page's
    /// bridge reads it before doing anything on the user's behalf, such as opening a link.
    var isUserPresent: Bool { get set }

    func load()

    /// Stops the loading and closes the page's web layer for good: a cancelled page can no
    /// longer be talked to, so a rendered page that may come back into the window must not be
    /// cancelled.
    func cancel()

    /// Tells the page its config changed, handing it the params the config now carries.
    ///
    /// The page re-runs its own pipeline from there, re-asking what it may render — so this is
    /// what re-evaluates targeting and an A/B re-flip on a live page.
    func sendInitData(params: [String: JSONValue])
}
