//
//  InAppWebViewLearnedHostsStoreTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 06.07.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import Testing
@testable import Mindbox

@Suite("InApp WebView learned hosts store", .tags(.webView))
struct InAppWebViewLearnedHostsStoreTests {

    private let storage = MockPersistenceStorage()
    private var store: InAppWebViewLearnedHostsStore {
        InAppWebViewLearnedHostsStore(persistenceStorage: storage)
    }

    @Test("Observed hosts merge in order without duplicates")
    func mergesWithoutDuplicates() {
        store.remember(["a.example", "b.example"], endpoint: "Endpoint")
        store.remember(["b.example", "c.example", ""], endpoint: "Endpoint")

        #expect(store.hosts(endpoint: "Endpoint") == ["a.example", "b.example", "c.example"])
    }

    @Test("The oldest hosts are dropped beyond the cap")
    func capsAtMaximumDroppingOldest() {
        let cap = InAppWebViewLearnedHostsStore.maxHosts

        store.remember((0..<cap).map { "host\($0).example" }, endpoint: "Endpoint")
        store.remember(["overflow.example"], endpoint: "Endpoint")

        let hosts = store.hosts(endpoint: "Endpoint")
        #expect(hosts.count == cap)
        #expect(hosts.first == "host1.example")
        #expect(hosts.last == "overflow.example")
    }

    @Test("Remembering nothing changes nothing")
    func emptyObservationIsNoOp() {
        store.remember([], endpoint: "Endpoint")
        store.remember(["not a host!"], endpoint: "Endpoint")

        #expect(store.hosts(endpoint: "Endpoint").isEmpty)
        #expect(storage.webViewLearnedHosts == nil)
    }

    @Test("Page-controlled strings that are not bare hosts are rejected on write")
    func rejectsNonHostStrings() {
        // The values come from page JS and are later interpolated into preconnect HTML —
        // anything that is not a bare RFC 1123 host must never be persisted.
        store.remember(
            [
                "cdn.ok.example",
                "x\"><script>alert(1)</script>",
                "bad host with spaces",
                "https://full.url/path",
                "host/with/path",
                "evil.example\"><link>",
                "a&b.example",
                ""
            ],
            endpoint: "Endpoint"
        )

        #expect(store.hosts(endpoint: "Endpoint") == ["cdn.ok.example"])
    }

    @Test("Re-remembering only known hosts does not rewrite storage")
    func noOpWriteWhenNothingNew() {
        store.remember(["a.example", "b.example"], endpoint: "Endpoint")
        let writesAfterFirst = storage.webViewLearnedHostsWriteCount

        // Every observed host is already known — the steady state after the first shows.
        // The persisted value is unchanged either way, so the write count is the only
        // observable proof the redundant UserDefaults write is skipped.
        store.remember(["a.example", "b.example"], endpoint: "Endpoint")
        #expect(storage.webViewLearnedHostsWriteCount == writesAfterFirst)

        // A genuinely new host still writes.
        store.remember(["c.example"], endpoint: "Endpoint")
        #expect(storage.webViewLearnedHostsWriteCount == writesAfterFirst + 1)
        #expect(store.hosts(endpoint: "Endpoint") == ["a.example", "b.example", "c.example"])
    }

    @Test("Hosts are scoped per endpoint")
    func endpointsAreIsolated() {
        store.remember(["a.example"], endpoint: "First")
        store.remember(["b.example"], endpoint: "Second")

        #expect(store.hosts(endpoint: "First") == ["a.example"])
        #expect(store.hosts(endpoint: "Second") == ["b.example"])
    }
}
