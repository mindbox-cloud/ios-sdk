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

    /// The page rendered `count` pieces of content, once per load. `0` means the page is alive
    /// and correct and has nothing to show. Delivered on the main thread.
    var onContentRendered: ((Int) -> Void)? { get set }

    /// The page reported content, but the report could not be read — the block holds a show
    /// nobody can vouch for. Delivered on the main thread.
    var onUnreadableContentReport: (() -> Void)? { get set }

    /// The page asks which of these ids are showable. The answer goes back through `completion`
    /// — from wherever the selection finishes. Delivered on the main thread.
    var onShowableQuestion: (([String], @escaping ([String]) -> Void) -> Void)? { get set }

    /// The page asks to show an in-app by id, with the params that travel into its start
    /// payload untouched. Delivered on the main thread.
    var onShowInAppRequest: ((String, [String: JSONValue]) -> Void)? { get set }

    /// The page confirmed the `initDataUpdated` push. Delivered on the main thread.
    var onDataPushConfirmed: (() -> Void)? { get set }

    /// The page failed to load — the markup fetch or the navigation itself. Delivered on the
    /// main thread.
    var onLoadFailure: (() -> Void)? { get set }

    /// Whether the block is on screen for the user. The provider keeps it current; the page's
    /// bridge reads it before doing anything on the user's behalf, such as opening a link.
    var isUserPresent: Bool { get set }

    func load()

    /// Closes the page's web layer for good: a cancelled page can no longer be talked to, so a
    /// rendered page that may come back into the window must not be cancelled.
    func cancel()

    /// Hands the page the params its config now carries. The page re-runs its own pipeline from
    /// there — this is what re-evaluates targeting and an A/B re-flip on a live page.
    func sendInitData(params: [String: JSONValue])
}
