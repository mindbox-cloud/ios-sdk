//
//  EmbeddedBlockWebViewProvider.swift
//  Mindbox
//
//  Created by vailence on 03.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit
import MindboxLogger

/// Embedded block content — a web page found by the block id.
///
/// The provider does not draw content and knows no mechanics: it asks the resolver what stands
/// behind the id, translates the page's core messages into container states, and hands actions
/// beyond the core layer to the universal handler.
///
/// An instance belongs to one container, so `start()` and `stop()` simply mirror its visibility
/// and can be called in cycles. After `stop()` the provider must stay silent until the next
/// `start()` — the container relies on this when it collapses an expired block.
final class EmbeddedBlockWebViewProvider {

    /// Reports every state change on the main thread. Set by the container.
    var onStateChange: ((EmbeddedBlockState) -> Void)?

    var contentView: UIView? { isReady ? page?.view : nil }

    private let id: String
    private let resolver: EmbeddedBlockResolving
    private let actionHandler: EmbeddedBlockActionHandling
    private let readinessOverrides: EmbeddedBlockReadinessOverriding
    private let makePage: (EmbeddedBlockWebContent) -> EmbeddedBlockPageHosting

    /// The page survives restarts: the container starts and stops the block by visibility, and
    /// there is no reason to recreate the web view on every return to the window.
    private var page: EmbeddedBlockPageHosting?

    private var isStarted = false

    /// How the current attempt ended: `nil` — nothing yet.
    ///
    /// The outcome survives `stop()`: it is a property of the page, not of being in the window.
    /// A failure and `empty` do not kill the page — it is alive and can keep talking — so a known
    /// outcome is also needed as a sign that the block is no longer on screen.
    private var outcome: EmbeddedBlockState?

    private var isReady: Bool { outcome == .ready }

    /// The number of the current load attempt. A resolve may answer after `stop()` or after a
    /// reload — the number shows that the answer belongs to a past attempt and must be thrown away.
    private var loadGeneration = 0

    init(id: String,
         resolver: EmbeddedBlockResolving,
         actionHandler: EmbeddedBlockActionHandling,
         readinessOverrides: EmbeddedBlockReadinessOverriding = EmbeddedBlockReadinessOverrides.shared,
         makePage: @escaping (EmbeddedBlockWebContent) -> EmbeddedBlockPageHosting) {
        self.id = id
        self.resolver = resolver
        self.actionHandler = actionHandler
        self.readinessOverrides = readinessOverrides
        self.makePage = makePage

        EmbeddedBlockWebViewProvider.blockCreated(id: id)
    }

    deinit {
        EmbeddedBlockWebViewProvider.blockReleased(id: id)
    }

    func start() {
        start(forceRefresh: false)
    }

    func stop() {
        guard isStarted else { return }

        isStarted = false
        // The outcome is not reset: it is a property of the page, not of being in the window.
        // Otherwise every pass of the block across the screen would cost a full reload.
        loadGeneration += 1
        page?.cancel()
    }

    /// Starts the load from scratch: drops the page and requests the address again, bypassing the
    /// resolver cache — otherwise a moved or disabled block would forever get its previous address.
    func reload() {
        Logger.common(message: "[EmbeddedBlock] Block '\(id)' is reloading", category: .embeddedBlocks)

        // The previous page is no longer relevant — detach it from us first so that its late
        // messages do not end up in the new attempt.
        page?.onMessage = nil
        page?.onLoadFailure = nil
        page?.onLoadFinish = nil
        page?.cancel()
        page = nil

        isStarted = false
        outcome = nil
        loadGeneration += 1

        start(forceRefresh: true)
    }

    func handle(_ message: EmbeddedBlockPageMessage) {
        guard isStarted else { return }

        switch message {
        case .ready(let height):
            apply(height: height)
        case .heightChanged(let height):
            // The host owns the height — the message stays in the page contract but affects
            // nothing on the native side.
            Logger.common(message: "[EmbeddedBlock] Ignored heightChanged(\(height)): the host owns the container height", category: .embeddedBlocks)
        case .empty:
            outcome = .empty
            onStateChange?(.empty)
        case .action(let action):
            // The block is not on screen, but the page is alive and keeps working — for example,
            // delivering what its `setTimeout` scheduled. Its actions must not run at this moment:
            // not a single user touch stands behind an invisible block, and `openUrl` would take
            // the user out of the app out of nowhere.
            guard isShown else {
                Logger.common(message: "[EmbeddedBlock] Block '\(id)': ignored action '\(action.type)' from a block that is not shown",
                              category: .embeddedBlocks)
                return
            }

            actionHandler.handle(action)
        }
    }

    func handleLoadFailure() {
        guard isStarted else { return }

        outcome = .failed
        onStateChange?(.failed)
    }

    /// While there is no outcome, the page is still loading — its messages belong to a live block.
    private var isShown: Bool {
        outcome == nil || outcome == .ready
    }

    /// A loaded document means nothing by itself: showing the block on it is allowed only by the
    /// debug override — for pages that cannot send `ready` yet.
    func handleLoadFinish() {
        guard isStarted, !isReady, readinessOverrides.treatsLoadedPageAsReady else { return }

        Logger.common(message: "[EmbeddedBlock] Block '\(id)': debug readiness is ON, showing the loaded page without a 'ready' from it",
                      level: .default,
                      category: .embeddedBlocks)
        outcome = .ready
        onStateChange?(.ready)
    }

    private func start(forceRefresh: Bool) {
        guard !isStarted else { return }

        isStarted = true

        // The page has already rendered and is still around — show it as is. Returning the block
        // to the window costs no network, no shimmer, no repeated events to the host.
        if isReady, page != nil {
            Logger.common(message: "[EmbeddedBlock] Block '\(id)': showing the page rendered earlier",
                          category: .embeddedBlocks)
            onStateChange?(.ready)
            return
        }

        onStateChange?(.loading)
        // A new attempt has started: how the previous one ended no longer matters — including for
        // deciding whether to run the page's actions.
        outcome = nil

        if let page {
            page.load()
            return
        }

        let generation = loadGeneration
        resolver.resolve(id, forceRefresh: forceRefresh) { [weak self] resolution in
            guard let self, self.isStarted, self.loadGeneration == generation else { return }

            switch resolution {
            case .empty:
                Logger.common(message: "[EmbeddedBlock] Block id '\(self.id)' resolved as empty",
                              category: .embeddedBlocks)
                self.onStateChange?(.empty)
            case .content(let content):
                let page = self.makePage(content)
                page.onMessage = { [weak self] message in
                    self?.handle(message)
                }
                page.onLoadFailure = { [weak self] in
                    self?.handleLoadFailure()
                }
                page.onLoadFinish = { [weak self] in
                    self?.handleLoadFinish()
                }
                self.page = page
                page.load()
            }
        }
    }

    private func apply(height: CGFloat) {
        // The page reports "nothing to show" with an explicit `empty`, so zero height means
        // broken layout, that is, a failure.
        guard height > 0 else {
            Logger.common(message: "[EmbeddedBlock] Block '\(id)': page reported zero height, treating as broken", category: .embeddedBlocks)
            outcome = .empty
            onStateChange?(.failed)
            return
        }

        Logger.common(message: "[EmbeddedBlock] Block '\(id)': page is ready", category: .embeddedBlocks)
        outcome = .ready
        onStateChange?(.ready)
    }
}

// MARK: - Live blocks

/// How many blocks with each id are alive right now.
///
/// Diagnostics, not mechanics: two blocks with one id are a legitimate case, both will show the
/// same content. But more often it is either a copied id or a reused cell that got a block
/// container from another row — and neither case has noticeable symptoms beyond "the block ended
/// up not where it was expected". So the SDK reports it to the log.
///
/// The counter is process-wide because the question is too: identical ids are looked for not
/// inside one block but across blocks. It does not retain live blocks — it stores only counts.
extension EmbeddedBlockWebViewProvider {

    private static var liveBlocks: [String: Int] = [:]

    /// Blocks are created and die with UIKit views, that is, on the main thread. The lock is here
    /// in case that ever stops being true: diagnostics must not crash the SDK.
    private static let liveBlocksLock = NSLock()

    static func liveCount(for id: String) -> Int {
        liveBlocksLock.lock()
        defer { liveBlocksLock.unlock() }

        return liveBlocks[id] ?? 0
    }

    fileprivate static func blockCreated(id: String) {
        liveBlocksLock.lock()
        let count = (liveBlocks[id] ?? 0) + 1
        liveBlocks[id] = count
        liveBlocksLock.unlock()

        guard count > 1 else { return }

        Logger.common(message: """
        [EmbeddedBlock] \(count) live blocks share id '\(id)'. They show the same content, \
        each rendered on its own. If that is unexpected, check that a reusable cell is not carrying \
        a block container from another row: a block is created for one id and cannot be repointed.
        """, category: .embeddedBlocks)
    }

    fileprivate static func blockReleased(id: String) {
        liveBlocksLock.lock()
        let remaining = max(0, (liveBlocks[id] ?? 1) - 1)
        if remaining > 0 {
            liveBlocks[id] = remaining
        } else {
            liveBlocks.removeValue(forKey: id)
        }
        liveBlocksLock.unlock()

        Logger.common(message: "[EmbeddedBlock] Block '\(id)' is released, \(remaining) live with this id",
                      category: .embeddedBlocks)
    }
}
