//
//  ReadyActionHandlerTests.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
@_spi(Internal) @testable import Mindbox

@Suite("ReadyActionHandler", .tags(.webView))
struct ReadyActionHandlerTests {

    @Test("Owns the ready action")
    func ownsReady() {
        #expect(ReadyActionHandler().actions == [.ready])
    }

    /// `ready` is deferred: the blanket `{success: true}` would tell the page nothing, and this
    /// is the one answer it cannot start without.
    @Test("Answers with the page's own start payload")
    func answersWithHostPayload() throws {
        let host = HostSpy()
        host.startPayload = .string(#"{"sdkVersion":"2.15.2"}"#)
        let message = BridgeMessage.request(.ready)

        ReadyActionHandler().handle(message, host: host)

        let response = try #require(host.sent.first)
        #expect(response.type == .response)
        #expect(response.action == message.action)
        #expect(response.id == message.id)
        #expect(response.payload == .string(#"{"sdkVersion":"2.15.2"}"#))
    }

    /// Composing the payload belongs to the host — an in-app knows its operation, a block knows
    /// its configuration entry — so the handler must not add to it or reshape it.
    @Test("Passes the payload through untouched")
    func passesPayloadThrough() {
        let host = HostSpy()
        host.startPayload = .object(["anything": .bool(true)])

        ReadyActionHandler().handle(.request(.ready), host: host)

        #expect(host.sent.first?.payload == .object(["anything": .bool(true)]))
    }

    @Test("Answers exactly once")
    func answersOnce() {
        let host = HostSpy()

        ReadyActionHandler().handle(.request(.ready), host: host)

        #expect(host.sent.count == 1)
    }
}
