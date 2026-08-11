//
//  EmbeddedBlockReadinessOverrides.swift
//  Mindbox
//
//  Created by vailence on 07.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

/// A debug override of the block readiness condition.
protocol EmbeddedBlockReadinessOverriding: AnyObject {

    /// `true` — the block becomes ready on the fact of a loaded document, without waiting for
    /// `ready` from the page.
    var treatsLoadedPageAsReady: Bool { get }
}

/// A temporary crutch for pages that do not implement the web contract yet.
///
/// The block's usual rule is that only the page itself declares readiness: a loaded document says
/// nothing about whether the block has anything to show, so a silent page is finished off by the
/// container timeout. While the contract is not implemented on the web side, checking the block
/// layout under this rule is impossible: any page collapses to zero on the timeout.
///
/// The override lifts exactly this restriction and nothing more: the document has loaded — we show
/// it. It is off by default and turned on only explicitly from the app code, because with the
/// override on a broken page looks like a working one — which is exactly what the usual rule
/// protects against.
///
/// Goes away together with the first page that learns to send `ready`.
final class EmbeddedBlockReadinessOverrides: EmbeddedBlockReadinessOverriding {

    static let shared = EmbeddedBlockReadinessOverrides()

    /// The flag is set from the app code, while the provider reads it on the main thread — the
    /// threads may differ.
    private let lock = NSLock()

    private var isLoadedPageTreatedAsReady = false

    var treatsLoadedPageAsReady: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isLoadedPageTreatedAsReady
    }

    func setTreatsLoadedPageAsReady(_ isEnabled: Bool) {
        lock.lock()
        let didChange = isLoadedPageTreatedAsReady != isEnabled
        isLoadedPageTreatedAsReady = isEnabled
        lock.unlock()

        guard didChange else { return }

        Logger.common(message: "[EmbeddedBlock] Debug readiness is \(isEnabled ? "ON" : "OFF"): a loaded page \(isEnabled ? "is" : "is no longer") treated as ready without the page contract",
                      level: .default,
                      category: .embeddedBlocks)
    }
}
