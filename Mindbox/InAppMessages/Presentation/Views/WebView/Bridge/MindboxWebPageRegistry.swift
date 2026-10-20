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

    func push(_ action: BridgeMessage.Action, payload: JSONValue)
}

final class MindboxWebPageRegistry {

    static let shared = MindboxWebPageRegistry()

    private var pages: [WeakPage] = []

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

    private func sweep() {
        pages.removeAll { $0.page == nil }
    }

    private struct WeakPage {
        weak var page: MindboxWebPage?
    }
}
