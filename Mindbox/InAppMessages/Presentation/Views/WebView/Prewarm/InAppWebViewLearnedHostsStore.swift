//
//  InAppWebViewLearnedHostsStore.swift
//  Mindbox
//
//  Created by Sergei Semko on 06.07.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

/// Persists resource hosts observed during real shows, per endpoint. These are the hosts
/// the config cannot know (image CDNs, the web runtime's static hosts, fonts) and they
/// let the next launch's preconnect cover the heavy part of the page. A stale entry is
/// harmless — preconnect to an unused host is a no-op. Backed by `PersistenceStorage`
/// like the rest of the SDK's state.
final class InAppWebViewLearnedHostsStore {
    static let maxHosts = 12

    private let persistenceStorage: PersistenceStorage

    init(persistenceStorage: PersistenceStorage) {
        self.persistenceStorage = persistenceStorage
    }

    func hosts(endpoint: String) -> [String] {
        persistenceStorage.webViewLearnedHosts?[endpoint] ?? []
    }

    /// Appends newly observed hosts, keeping insertion order and dropping the oldest
    /// beyond the cap. Values come from page JS — only bare https hosts are accepted.
    ///
    /// Main-thread only: this is an unsynchronized read-modify-write, safe because the
    /// single caller (the show's evaluateJavaScript completion) always runs on main.
    func remember(_ observed: [String], endpoint: String) {
        guard !observed.isEmpty else { return }
        var all = persistenceStorage.webViewLearnedHosts ?? [:]
        var merged = all[endpoint] ?? []
        var didAppend = false
        for host in observed where InAppWebViewPrewarmPlanner.isValidHost(host) && !merged.contains(host) {
            merged.append(host)
            didAppend = true
        }
        // Steady state after the first shows: every observed host is already known. Skip
        // the app-group UserDefaults rewrite (a synchronous cfprefsd round-trip on the
        // main thread) when nothing was added.
        guard didAppend else { return }
        if merged.count > Self.maxHosts {
            merged.removeFirst(merged.count - Self.maxHosts)
        }
        all[endpoint] = merged
        persistenceStorage.webViewLearnedHosts = all
    }
}
