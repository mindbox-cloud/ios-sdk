//
//  TargetingAndShowStubTests.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
@_spi(Internal) @testable import Mindbox

/// Both actions are answered but not yet implemented. What these pin is the shape of the answer:
/// the page reads `payload.inappIds` and throws if it is absent, and it gives up after three
/// seconds — so an answer of the wrong shape and no answer at all look the same from the feed.
@Suite("CheckInappsTargetingActionHandler", .tags(.webView))
struct CheckInappsTargetingActionHandlerTests {

    @Test("Owns the checkInappsTargeting action")
    func ownsAction() {
        #expect(CheckInappsTargetingActionHandler().actions == [.checkInappsTargeting])
    }

    /// Nothing is filtered yet, so the feed renders whole and the rest of the contract can be
    /// exercised.
    @Test("Every requested id is let through, in the order it was asked about")
    func letsEveryIdThrough() throws {
        let host = HostSpy()
        let ids: [JSONValue] = [.string("id-1"), .string("id-2"), .string("id-3")]

        CheckInappsTargetingActionHandler().handle(.request(.checkInappsTargeting,
                                                            payload: .object(["inappIds": .array(ids)])),
                                                   host: host)

        let response = try #require(host.sent.first)
        #expect(response.type == .response)
        #expect(response.payload == .object(["inappIds": .array(ids)]))
    }

    @Test("An empty request is answered with an empty list rather than an error")
    func emptyRequestIsAnsweredEmpty() {
        let host = HostSpy()

        CheckInappsTargetingActionHandler().handle(.request(.checkInappsTargeting,
                                                            payload: .object(["inappIds": .array([])])),
                                                   host: host)

        #expect(host.sent.first?.payload == .object(["inappIds": .array([])]))
    }

    @Test("Non-string entries are dropped instead of breaking the answer")
    func nonStringEntriesAreDropped() {
        let host = HostSpy()

        CheckInappsTargetingActionHandler().handle(
            .request(.checkInappsTargeting, payload: .object(["inappIds": .array([.string("id-1"), .int(7)])])),
            host: host
        )

        #expect(host.sent.first?.payload == .object(["inappIds": .array([.string("id-1")])]))
    }

    @Test("A payload without the array is refused")
    func missingArrayIsRefused() throws {
        let host = HostSpy()

        CheckInappsTargetingActionHandler().handle(.request(.checkInappsTargeting, payload: .object([:])), host: host)

        let response = try #require(host.sent.first)
        #expect(response.type == .error)
        #expect(response.payload == .object(["error": .string("Invalid payload: missing 'inappIds' array")]))
    }

    @Test("A payload sent as a JSON string is understood too")
    func acceptsStringifiedPayload() {
        let host = HostSpy()

        CheckInappsTargetingActionHandler().handle(.request(.checkInappsTargeting,
                                                            payload: .string(#"{"inappIds":["id-1"]}"#)),
                                                   host: host)

        #expect(host.sent.first?.payload == .object(["inappIds": .array([.string("id-1")])]))
    }
}

@Suite("ShowInAppActionHandler", .tags(.webView))
struct ShowInAppActionHandlerTests {

    @Test("Owns the showInApp action")
    func ownsAction() {
        #expect(ShowInAppActionHandler().actions == [.showInApp])
    }

    /// Nothing opens yet, but the page is answered so it can finish its own flow instead of
    /// waiting on a promise that never settles.
    @Test("A well-formed request is acknowledged")
    func requestIsAcknowledged() throws {
        let host = HostSpy()
        let message = BridgeMessage.request(.showInApp, payload: .object([
            "inappId": .string("11111111-1111-1111-1111-111111111111"),
            "index": .int(0),
            "sourceInappId": .string("feed"),
            "params": .object(["title": .string("Сториз 1")])
        ]))

        ShowInAppActionHandler().handle(message, host: host)

        let response = try #require(host.sent.first)
        #expect(response.type == .response)
        #expect(response.payload == .object(["success": .bool(true)]))
        #expect(response.id == message.id)
    }

    @Test("Only the id is required")
    func onlyIdIsRequired() {
        let host = HostSpy()

        ShowInAppActionHandler().handle(.request(.showInApp, payload: .object(["inappId": .string("some-id")])),
                                        host: host)

        #expect(host.sent.first?.type == .response)
    }

    @Test("A request without an id is refused", arguments: [
        JSONValue.object([:]),
        .object(["inappId": .string("")]),
        .object(["inappId": .int(1)])
    ])
    func missingIdIsRefused(payload: JSONValue) throws {
        let host = HostSpy()

        ShowInAppActionHandler().handle(.request(.showInApp, payload: payload), host: host)

        let response = try #require(host.sent.first)
        #expect(response.type == .error)
        #expect(response.payload == .object(["error": .string("Invalid payload: missing or empty 'inappId'")]))
    }
}
