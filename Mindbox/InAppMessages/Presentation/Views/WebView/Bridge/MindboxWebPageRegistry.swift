//
//  MindboxWebPageRegistry.swift
//  Mindbox
//
//  Created by Sergei Semko on 8/13/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

protocol MindboxWebPage: AnyObject {

    /// Takes an action and payload rather than a ready-made message — an id identifies one request
    /// on one channel, so every page mints its own. A closing page is free to drop the request.
    func push(_ action: BridgeMessage.Action, payload: JSONValue)
}

/// Every live bridge page in the process. Entries are weak: deregistration is the owner letting go.
final class MindboxWebPageRegistry {

    /// Tests build their own registry instead of resetting this one.
    static let shared = MindboxWebPageRegistry()

    private var pages: [WeakPage] = []

    /// Pages live and die with UIKit views (main thread today); the lock guards the day that
    /// stops being true.
    private let lock = NSLock()

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

    /// The author is excluded here rather than page-side: pages cannot tell each other apart.
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
