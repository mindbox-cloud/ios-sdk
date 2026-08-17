//
//  MindboxWebPageRegistryTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 8/13/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import Testing
@_spi(Internal) @testable import Mindbox

/// Each test builds its own registry: the shared one is process-wide and would couple the cases.
@Suite("MindboxWebPageRegistry", .tags(.webView))
struct MindboxWebPageRegistryTests {

    @Test("Everyone but the author hears a broadcast")
    func broadcastReachesEveryoneButTheAuthor() {
        let registry = MindboxWebPageRegistry()
        let author = WebPageSpy()
        let feed = WebPageSpy()
        let other = WebPageSpy()

        [author, feed, other].forEach(registry.register)

        registry.broadcast(.localStateChanged, payload: .object(["version": .int(1)]), excluding: author)

        #expect(author.received.isEmpty)
        #expect(feed.received.map(\.action) == [.localStateChanged])
        #expect(other.received.map(\.action) == [.localStateChanged])
    }

    @Test("A lone author hears nothing")
    func aLoneAuthorHearsNothing() {
        let registry = MindboxWebPageRegistry()
        let author = WebPageSpy()
        registry.register(author)

        registry.broadcast(.localStateChanged, payload: .object([:]), excluding: author)

        #expect(author.received.isEmpty)
    }

    @Test("With no author excluded every page hears it")
    func withoutAnAuthorEveryPageHearsIt() {
        let registry = MindboxWebPageRegistry()
        let page = WebPageSpy()
        registry.register(page)

        registry.broadcast(.initDataUpdated, payload: .string("{}"), excluding: nil)

        #expect(page.received.map(\.action) == [.initDataUpdated])
    }

    @Test("Each page gets its own payload copy under its own request")
    func eachPageGetsItsOwnRequest() {
        let registry = MindboxWebPageRegistry()
        let first = WebPageSpy()
        let second = WebPageSpy()
        [first, second].forEach(registry.register)

        registry.broadcast(.localStateChanged, payload: .object(["version": .int(7)]), excluding: nil)

        #expect(first.received.first?.payload == .object(["version": .int(7)]))
        #expect(second.received.first?.payload == .object(["version": .int(7)]))
    }

    @Test("A released page leaves the registry by itself")
    func aReleasedPageLeavesByItself() {
        let registry = MindboxWebPageRegistry()
        let survivor = WebPageSpy()
        registry.register(survivor)

        do {
            let temporary = WebPageSpy()
            registry.register(temporary)
            #expect(registry.count == 2)
        }

        #expect(registry.count == 1)

        registry.broadcast(.localStateChanged, payload: .object([:]), excluding: nil)

        #expect(survivor.received.count == 1)
    }

    @Test("Registering the same page twice does not double its messages")
    func registeringTwiceDoesNotDoubleMessages() {
        let registry = MindboxWebPageRegistry()
        let page = WebPageSpy()

        registry.register(page)
        registry.register(page)

        #expect(registry.count == 1)

        registry.broadcast(.localStateChanged, payload: .object([:]), excluding: nil)

        #expect(page.received.count == 1)
    }

    @Test("A broadcast with no live page is not an error")
    func broadcastWithNoLivePageIsNotAnError() {
        let registry = MindboxWebPageRegistry()

        registry.broadcast(.localStateChanged, payload: .object([:]), excluding: nil)

        #expect(registry.count == 0)
    }
}

private final class WebPageSpy: MindboxWebPage {

    private(set) var received: [(action: BridgeMessage.Action, payload: JSONValue)] = []

    func push(_ action: BridgeMessage.Action, payload: JSONValue) {
        received.append((action, payload))
    }
}
