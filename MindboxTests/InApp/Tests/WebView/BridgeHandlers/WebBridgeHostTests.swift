//
//  WebBridgeHostTests.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
@_spi(Internal) @testable import Mindbox

/// The answers a host builds for a handler.
///
/// Every one of them is built from the request itself rather than from arguments a handler passes,
/// which is what keeps an answer from drifting away from the thing it answers. That is the whole
/// subject here: identity travels, and the envelope matches its kind.
@Suite("WebBridgeHost responses", .tags(.webView))
struct WebBridgeHostResponseTests {

    @Test("A success response carries the request's own id and action")
    func successKeepsIdentity() throws {
        let host = HostSpy()
        let message = BridgeMessage(type: .request, action: BridgeMessage.Action.log.rawValue, payload: nil)

        host.respondSuccess(to: message)

        let response = try #require(host.sent.first)
        #expect(response.id == message.id)
        #expect(response.action == message.action)
        #expect(response.type == .response)
        #expect(response.payload == .object(["success": .bool(true)]))
    }

    @Test("An error response is typed as an error and carries the reason")
    func errorCarriesReason() throws {
        let host = HostSpy()
        let message = BridgeMessage(type: .request, action: BridgeMessage.Action.haptic.rawValue, payload: nil)

        host.respondError("Invalid payload", to: message)

        let response = try #require(host.sent.first)
        #expect(response.id == message.id)
        #expect(response.action == message.action)
        #expect(response.type == .error)
        #expect(response.payload == .object(["error": .string("Invalid payload")]))
    }

    @Test("A content response carries the payload it was given")
    func responseCarriesPayload() {
        let host = HostSpy()
        let message = BridgeMessage(type: .request, action: BridgeMessage.Action.localStateGet.rawValue, payload: nil)
        let payload = JSONValue.object(["data": .object(["key": .string("value")]), "version": .int(1)])

        host.respond(to: message, payload: payload)

        #expect(host.sent.first?.payload == payload)
    }

    /// One request, one answer: a handler that answers twice would be talking against an id JS has
    /// already closed, so nothing in the envelope-building path may fan out on its own.
    @Test("Answering once sends exactly one message")
    func answeringOnceSendsOne() {
        let host = HostSpy()

        host.respondSuccess(to: .request(.log))

        #expect(host.sent.count == 1)
    }
}
