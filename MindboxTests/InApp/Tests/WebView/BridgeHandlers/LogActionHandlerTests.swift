//
//  LogActionHandlerTests.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import MindboxLogger
@_spi(Internal) @testable import Mindbox

@Suite("LogActionHandler", .tags(.webView))
struct LogActionHandlerTests {

    @Test("Owns the log action and nothing else")
    func ownsLogOnly() {
        #expect(LogActionHandler().actions == [.log])
    }

    /// `log` is not deferred, so `RequestMessageHandler` has already sent `{success: true}` by
    /// the time the handler runs. A second answer would arrive against an id JS has closed.
    @Test("Never answers: the dispatcher already acknowledged this action")
    func neverAnswers() {
        let host = HostSpy()

        LogActionHandler().handle(.request(.log, payload: .string("hello from the page")), host: host)

        #expect(host.sent.isEmpty)
    }

    @Test("Runs whatever shape the payload arrived in")
    func toleratesEveryPayloadShape() {
        let host = HostSpy()
        let handler = LogActionHandler()

        handler.handle(.request(.log, payload: .string("a string")), host: host)
        handler.handle(.request(.log, payload: .object(["message": .string("an object")])), host: host)
        handler.handle(.request(.log, payload: nil), host: host)

        #expect(host.sent.isEmpty)
    }
}

@Suite("BridgeMessage payloadString", .tags(.webView))
struct BridgeMessagePayloadStringTests {

    @Test("A string payload is taken as it is — the ordinary case from JS")
    func stringPayloadPassesThrough() {
        let message = BridgeMessage.request(.log, payload: .string("{\"message\":\"hi\"}"))

        #expect(message.payloadString == "{\"message\":\"hi\"}")
    }

    @Test("An already-decoded payload is re-encoded, not described")
    func objectPayloadIsReencoded() {
        let message = BridgeMessage.request(.log, payload: .object(["message": .string("hi")]))

        // Re-encoded as JSON, so a handler sees the same text whichever shape the page sent.
        #expect(message.payloadString == "{\"message\":\"hi\"}")
    }

    @Test("A missing payload reads as empty rather than as a literal nil")
    func missingPayloadIsEmpty() {
        let message = BridgeMessage.request(.log, payload: nil)

        #expect(message.payloadString.isEmpty)
    }
}
