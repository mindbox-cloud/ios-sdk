//
//  MindboxWebPageRegistry.swift
//  Mindbox
//
//  Created by Sergei Semko on 8/13/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

/// A live page on the JS bridge that the SDK can push into.
///
/// Pushing takes an action and a payload rather than a ready-made message: an id identifies one
/// request on one channel, so every page has to get its own.
protocol MindboxWebPage: AnyObject {

    /// Sends a Native → JS request to this page. A page that is closing is free to drop it: there
    /// is no one left to answer, and a broadcast must not care who did.
    func push(_ action: BridgeMessage.Action, payload: JSONValue)
}

/// Every live bridge page in the process, in one place.
///
/// A page is not a screen. An overlay in-app, an embedded block, and a story opened out of that
/// block are three pages at the same time, and `localState.changed` has to reach all of them
/// except the one that wrote the value — that is how a feed greys a ring while the story that
/// just finished is still on top of it. No view can do that on its own: each one knows only its
/// own page.
///
/// Entries are weak. A page leaves the set exactly when its owner lets go of it: nothing to
/// unregister, nothing to leak, no way to answer for a page that is already gone. Dead entries
/// are swept on the next visit.
final class MindboxWebPageRegistry {

    /// The process-wide set. Tests build their own registry instead of resetting this one.
    static let shared = MindboxWebPageRegistry()

    private var pages: [WeakPage] = []

    /// Pages are created and released together with UIKit views, that is, on the main thread. The
    /// lock is here in case that ever stops being true: a broadcast must not become the reason
    /// the SDK crashes.
    private let lock = NSLock()

    /// How many live pages are registered. Sweeps as it counts, so it also answers "did that page
    /// actually go away".
    var count: Int {
        lock.lock()
        defer { lock.unlock() }

        sweep()
        return pages.count
    }

    func register(_ page: MindboxWebPage) {
        lock.lock()
        sweep()

        guard !pages.contains(where: { $0.page === page }) else {
            lock.unlock()
            return
        }

        pages.append(WeakPage(page: page))
        let count = pages.count
        lock.unlock()

        Logger.common(message: "[WebView] Registry: page registered, \(count) live",
                      category: .webViewInAppMessages)
    }

    /// Sends the same action to every live page but `author`.
    ///
    /// The author is excluded rather than filtered on the page side because only the SDK knows
    /// which page asked: the pages themselves cannot tell each other apart.
    func broadcast(_ action: BridgeMessage.Action, payload: JSONValue, excluding author: AnyObject?) {
        lock.lock()
        sweep()
        let receivers = pages.compactMap(\.page).filter { $0 !== author }
        lock.unlock()

        guard !receivers.isEmpty else {
            Logger.common(message: "[WebView] Registry: nobody to receive '\(action.rawValue)'",
                          category: .webViewInAppMessages)
            return
        }

        Logger.common(message: "[WebView] Registry: broadcasting '\(action.rawValue)' to \(receivers.count) page(s)",
                      category: .webViewInAppMessages)

        receivers.forEach { $0.push(action, payload: payload) }
    }

    /// Callers hold the lock.
    private func sweep() {
        pages.removeAll { $0.page == nil }
    }

    private struct WeakPage {
        weak var page: MindboxWebPage?
    }
}
