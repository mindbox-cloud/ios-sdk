//
//  EmbeddedBlockResolver.swift
//  Mindbox
//
//  Created by vailence on 06.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

/// What an embedded block id resolves into.
enum EmbeddedBlockResolution: Equatable {

    /// There is content attached to the id — the block loads it.
    case content(EmbeddedBlockWebContent)

    /// There is nothing behind the id — the block is turned off in the admin panel or the id is
    /// unknown. Not an error.
    case empty
}

/// Answers a single question: what does the block with this id show.
///
/// The resolver is the shared point for every container: several blocks with the same id resolve
/// with the same data, while the view, the page and the state stay per block. Works on the main
/// thread; the completion may arrive either synchronously (cache) or later (remote config).
protocol EmbeddedBlockResolving: AnyObject {

    /// - Parameter forceRefresh: `true` — skip the cache, ask for the data again. Needed by a block
    ///   reload: a block that moved or was turned off would otherwise keep pulling the old address
    ///   from the cache forever. Laid down in advance and deliberately not exposed: while "once per
    ///   SDK initialization" holds, a reload cannot be triggered from the app.
    func resolve(_ id: String, forceRefresh: Bool, completion: @escaping (EmbeddedBlockResolution) -> Void)
}

extension EmbeddedBlockResolving {

    func resolve(_ id: String, completion: @escaping (EmbeddedBlockResolution) -> Void) {
        resolve(id, forceRefresh: false, completion: completion)
    }
}

/// Where the resolver learns what stands behind a block id.
///
/// For now it is a stub with a static page. Once the admin panel config arrives, the real loading
/// will live here, while the cache and the queue of waiters in the resolver stay unchanged.
///
/// It may answer from any thread: the resolver moves the answer to the main thread itself, because
/// that is where it updates the cache and the queue of waiters, and where the block views wait for
/// the answer.
typealias EmbeddedBlockContentLoading = (String, @escaping (EmbeddedBlockResolution) -> Void) -> Void

final class EmbeddedBlockResolver: EmbeddedBlockResolving {

    /// The stories feed page on static hosting. Hardcoded for now: once the admin panel config
    /// arrives, the address will come from there together with the id → content mapping.
    private static let storiesPageURL = "https://mobile-static.mindbox.ru/beta/inapps/webview/content/stories.html"

    private let load: EmbeddedBlockContentLoading
    private let overrides: EmbeddedBlockContentOverriding

    /// A cache per id: an answer received once is handed to every following block immediately.
    ///
    /// Lives until the end of the process and is never invalidated — including `.empty`. That is a
    /// decision, not an oversight: a block resolves once per SDK initialization, full stop. It
    /// follows that a block turned off in the admin panel, or one that did not make it at app
    /// startup, will not appear until a restart — and that is by design. This may change later, but
    /// for now it is so.
    private var cache: [String: EmbeddedBlockResolution] = [:]

    /// Who is already waiting for the answer for this id. "One data load per id" means that a
    /// second block with the same id joins this queue instead of going for the data itself.
    private var waiting: [String: [(EmbeddedBlockResolution) -> Void]] = [:]

    init(load: @escaping EmbeddedBlockContentLoading = EmbeddedBlockResolver.loadStubbedStoriesPage,
         overrides: EmbeddedBlockContentOverriding = EmbeddedBlockContentOverrides.shared) {
        self.load = load
        self.overrides = overrides
    }

    func resolve(_ id: String, forceRefresh: Bool, completion: @escaping (EmbeddedBlockResolution) -> Void) {
        // The cache and the queue of waiters are plain dictionaries: every path through them has to
        // run on one thread — the same one the block views wait on.
        guard Thread.isMainThread else {
            Logger.common(message: "[EmbeddedBlock] Resolver was asked about id '\(id)' off the main thread, continuing on it",
                          level: .error,
                          category: .embeddedBlocks)
            DispatchQueue.main.async { [weak self] in
                self?.resolve(id, forceRefresh: forceRefresh, completion: completion)
            }
            return
        }

        // The debug override outranks both the data and the cache: acceptance testing switches
        // scenarios on the fly, and a cached answer would get in the way.
        if let overridden = overrides.resolution(for: id) {
            completion(overridden)
            return
        }

        if !forceRefresh, let cached = cache[id] {
            completion(cached)
            return
        }

        // A load for this id is already in flight. Joining it is right for `forceRefresh` too: the
        // answer it is about to bring is fresh by definition.
        if waiting[id] != nil {
            waiting[id]?.append(completion)
            return
        }

        waiting[id] = [completion]

        load(id) { [weak self] resolution in
            guard Thread.isMainThread else {
                DispatchQueue.main.async {
                    self?.finish(id, with: resolution)
                }
                return
            }

            self?.finish(id, with: resolution)
        }
    }

    /// The answer has arrived: it goes into the cache and is handed to the whole queue that waited
    /// for it.
    private func finish(_ id: String, with resolution: EmbeddedBlockResolution) {
        cache[id] = resolution
        let completions = waiting.removeValue(forKey: id) ?? []
        completions.forEach { $0(resolution) }
    }

    /// There is no config yet, so any id resolves into the stories feed page. This is the single
    /// place the real admin panel config will replace: id → block content, a turned off or unknown
    /// block → `.empty`.
    static func loadStubbedStoriesPage(_ id: String, completion: @escaping (EmbeddedBlockResolution) -> Void) {
        guard let url = URL(string: storiesPageURL) else {
            Logger.common(message: "[EmbeddedBlock] Invalid stories page URL, resolving id '\(id)' as empty",
                          category: .embeddedBlocks)
            completion(.empty)
            return
        }

        Logger.common(message: "[EmbeddedBlock] Resolved block id '\(id)' to \(url.absoluteString)", category: .embeddedBlocks)
        completion(.content(EmbeddedBlockWebContent(url: url)))
    }
}
