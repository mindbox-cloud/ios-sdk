//
//  InAppWebViewLearnedHostsStore.swift
//  Mindbox
//
//  Created by Sergei Semko on 06.07.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

final class InAppWebViewLearnedHostsStore {
    static let maxHosts = 12

    private let persistenceStorage: PersistenceStorage

    init(persistenceStorage: PersistenceStorage) {
        self.persistenceStorage = persistenceStorage
    }

    func hosts(endpoint: String) -> [String] {
        persistenceStorage.webViewLearnedHosts?[endpoint] ?? []
    }

    // Main thread only: an unsynchronized read-modify-write.
    func remember(_ observed: [String], endpoint: String) {
        guard !observed.isEmpty else { return }
        var all = persistenceStorage.webViewLearnedHosts ?? [:]
        var merged = all[endpoint] ?? []
        var didAppend = false
        for host in observed where InAppWebViewPrewarmPlanner.isValidHost(host) && !merged.contains(host) {
            merged.append(host)
            didAppend = true
        }
        guard didAppend else { return }
        if merged.count > Self.maxHosts {
            merged.removeFirst(merged.count - Self.maxHosts)
        }
        all[endpoint] = merged
        persistenceStorage.webViewLearnedHosts = all
    }
}
