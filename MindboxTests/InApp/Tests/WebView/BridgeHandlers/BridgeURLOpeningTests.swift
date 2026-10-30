//
//  BridgeURLOpeningTests.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 14.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
@_spi(Internal) @testable import Mindbox

@Suite("BridgeURLOpening.open(answering:)", .tags(.webView))
@MainActor
struct BridgeURLOpeningTests {

    private let url = URL(string: "myapp://product/1")!

    @Test("A successful open is answered as a success")
    func successIsAnswered() async throws {
        let opener = URLOpenerSpy()
        opener.result = true
        let host = HostSpy()
        let message = BridgeMessage.request(.openLink)

        opener.open(url, answering: message, host: host)
        await drainMainQueue(until: { !host.sent.isEmpty })

        let response = try #require(host.sent.first)
        #expect(response.type == .response)
        #expect(response.payload == .object(["success": .bool(true)]))
        #expect(response.id == message.id)
        #expect(response.action == message.action)
    }

    @Test("A refused open is answered as open_failed")
    func failureIsAnswered() async throws {
        let opener = URLOpenerSpy()
        opener.result = false
        let host = HostSpy()
        let message = BridgeMessage.request(.openLink)

        opener.open(url, answering: message, host: host)
        await drainMainQueue(until: { !host.sent.isEmpty })

        let response = try #require(host.sent.first)
        #expect(response.type == .error)
        #expect(response.payload == .object(["error": .string("open_failed")]))
        #expect(response.id == message.id)
    }

    @Test("The system is asked without the universal-link restriction")
    func doesNotRestrictToUniversalLinks() async {
        let opener = URLOpenerSpy()
        let host = HostSpy()

        opener.open(url, answering: .request(.openLink), host: host)
        await drainMainQueue(until: { !opener.opened.isEmpty })

        #expect(opener.opened.map(\.universalLinksOnly) == [false])
    }

    @Test("The URL reaches the system unchanged")
    func urlReachesTheSystemUnchanged() async {
        let opener = URLOpenerSpy()
        let host = HostSpy()

        opener.open(url, answering: .request(.settingsOpen), host: host)
        await drainMainQueue(until: { !opener.opened.isEmpty })

        #expect(opener.opened.first?.url == url)
    }

    @Test("A page released while the system is deciding is not held by the request")
    func pendingOpenDoesNotHoldThePage() async {
        let opener = URLOpenerSpy()
        weak var page: HostSpy?

        do {
            let host = HostSpy()
            page = host
            opener.open(url, answering: .request(.openLink), host: host)
        }

        await drainMainQueue(until: { false }, turns: 3)

        #expect(page == nil)
    }
}
