//
//  EmbeddedBlockContentOverrides.swift
//  Mindbox
//
//  Created by vailence on 06.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

/// What to substitute for the content attached to a block id.
protocol EmbeddedBlockContentOverriding: AnyObject {

    func resolution(for id: String) -> EmbeddedBlockResolution?
}

/// A debug override of the block content — what acceptance testing uses to reproduce scenarios that
/// are not published on the network: an empty block, a silent page, an answer that comes after the
/// timeout, an unknown message.
///
/// The override sits in the place of the config, so the whole path below it — the resolver, the
/// provider, the page, the container timeout — works for real; only the source of the block data
/// changes. The resolver cache is not used for an overridden id, so that switching a scenario
/// applies right away.
///
/// Hidden behind `@_spi(Internal)`: it is absent from the regular API, but it is not stripped from
/// release builds either — QA checks what ships to clients. Every override that gets set is written
/// to the log, so an enabled override is impossible to miss.
final class EmbeddedBlockContentOverrides: EmbeddedBlockContentOverriding {

    static let shared = EmbeddedBlockContentOverrides()

    /// The override is set from the app's QA code, while the resolver reads it on the main thread —
    /// the threads may differ.
    private let lock = NSLock()

    private var overrides: [String: EmbeddedBlockResolution] = [:]

    func set(_ resolution: EmbeddedBlockResolution, for id: String) {
        lock.lock()
        overrides[id] = resolution
        lock.unlock()

        Logger.common(message: "[EmbeddedBlock] Debug override is ON for block id '\(id)': \(describe(resolution))",
                      level: .default,
                      category: .embeddedBlocks)
    }

    func remove(for id: String) {
        lock.lock()
        let removed = overrides.removeValue(forKey: id) != nil
        lock.unlock()

        guard removed else { return }
        Logger.common(message: "[EmbeddedBlock] Debug override is OFF for block id '\(id)'", category: .embeddedBlocks)
    }

    func removeAll() {
        lock.lock()
        let hadAny = !overrides.isEmpty
        overrides = [:]
        lock.unlock()

        guard hadAny else { return }
        Logger.common(message: "[EmbeddedBlock] All debug overrides are OFF", category: .embeddedBlocks)
    }

    func resolution(for id: String) -> EmbeddedBlockResolution? {
        lock.lock()
        defer { lock.unlock() }
        return overrides[id]
    }

    private func describe(_ resolution: EmbeddedBlockResolution) -> String {
        switch resolution {
        case .empty:
            return "empty"
        case .content(let content):
            switch content.source {
            case .url(let url): return url.absoluteString
            case .html: return "inline html"
            }
        }
    }
}
