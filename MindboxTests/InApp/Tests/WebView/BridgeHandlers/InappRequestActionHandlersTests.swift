//
//  InappRequestActionHandlersTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
@_spi(Internal) @testable import Mindbox

@Suite("FilterShowableInappsActionHandler", .tags(.webView))
struct FilterShowableInappsActionHandlerTests {

    @Test("Owns the filterShowableInapps action")
    func ownsAction() {
        #expect(FilterShowableInappsActionHandler().actions == [.filterShowableInapps])
    }

    @Test("The in-app service's answer travels back in the response")
    func serviceAnswerTravelsBack() throws {
        let host = InappRequestHostSpy()
        host.allowed = ["id-1", "id-3"]
        let message = BridgeMessage.request(.filterShowableInapps,
                                            payload: .object(["inappIds": .array([.string("id-1"),
                                                                                  .string("id-2"),
                                                                                  .string("id-3")])]))

        FilterShowableInappsActionHandler().handle(message, host: host)

        #expect(host.askedIds == [["id-1", "id-2", "id-3"]])
        let response = try #require(host.sent.first)
        #expect(response.type == .response)
        #expect(response.id == message.id)
        #expect(response.payload == .object(["inappIds": .array([.string("id-1"), .string("id-3")])]))
    }

    @Test("A late answer from the selection still becomes the response")
    func lateAnswerStillResponds() {
        let host = InappRequestHostSpy()
        host.isDeferred = true

        FilterShowableInappsActionHandler().handle(.request(.filterShowableInapps,
                                                            payload: .object(["inappIds": .array([.string("id-1")])])),
                                                   host: host)

        #expect(host.sent.isEmpty)

        host.allowed = ["id-1"]
        host.flush()

        #expect(host.sent.first?.payload == .object(["inappIds": .array([.string("id-1")])]))
    }

    @Test("An empty question is asked and answered, not refused")
    func emptyRequestIsAnswered() {
        let host = InappRequestHostSpy()

        FilterShowableInappsActionHandler().handle(.request(.filterShowableInapps,
                                                            payload: .object(["inappIds": .array([])])),
                                                   host: host)

        #expect(host.askedIds == [[]])
        #expect(host.sent.first?.payload == .object(["inappIds": .array([])]))
    }

    @Test("Non-string entries are dropped instead of breaking the question")
    func nonStringEntriesAreDropped() {
        let host = InappRequestHostSpy()
        host.allowed = ["id-1"]

        FilterShowableInappsActionHandler().handle(
            .request(.filterShowableInapps, payload: .object(["inappIds": .array([.string("id-1"), .int(7)])])),
            host: host
        )

        #expect(host.askedIds == [["id-1"]])
        #expect(host.sent.first?.payload == .object(["inappIds": .array([.string("id-1")])]))
    }

    @Test("A payload without the array is refused before the service is asked")
    func missingArrayIsRefused() throws {
        let host = InappRequestHostSpy()

        FilterShowableInappsActionHandler().handle(.request(.filterShowableInapps, payload: .object([:])), host: host)

        #expect(host.askedIds.isEmpty)
        let response = try #require(host.sent.first)
        #expect(response.type == .error)
        #expect(response.payload == .object(["error": .string("Invalid payload: missing 'inappIds' array")]))
    }

    @Test("A payload sent as a JSON string is understood too")
    func acceptsStringifiedPayload() {
        let host = InappRequestHostSpy()
        host.allowed = ["id-1"]

        FilterShowableInappsActionHandler().handle(.request(.filterShowableInapps,
                                                            payload: .string(#"{"inappIds":["id-1"]}"#)),
                                                   host: host)

        #expect(host.sent.first?.payload == .object(["inappIds": .array([.string("id-1")])]))
    }

    @Test("A host without an in-app service refuses the question instead of keeping silent")
    func hostWithoutInappServiceRefuses() throws {
        let host = HostSpy()

        FilterShowableInappsActionHandler().handle(.request(.filterShowableInapps,
                                                            payload: .object(["inappIds": .array([.string("id-1")])])),
                                                   host: host)

        let response = try #require(host.sent.first)
        #expect(response.type == .error)
        #expect(response.payload == .object(["error": .string("filterShowableInapps is not served on this surface")]))
    }
}

@Suite("ShowInAppActionHandler", .tags(.webView))
struct ShowInAppActionHandlerTests {

    @Test("Owns the showInApp action")
    func ownsAction() {
        #expect(ShowInAppActionHandler().actions == [.showInApp])
    }

    @Test("A well-formed request reaches the service and is answered only by the outcome")
    func requestReachesTheServiceAndWaitsForTheOutcome() throws {
        let host = InappRequestHostSpy()
        let message = BridgeMessage.request(.showInApp, payload: .object([
            "inappId": .string("11111111-1111-1111-1111-111111111111"),
            "index": .int(0),
            "sourceInappId": .string("block"),
            "params": .object(["title": .string("Сториз 1")])
        ]))

        ShowInAppActionHandler().handle(message, host: host)

        let shown = try #require(host.shown.first)
        #expect(shown.id == "11111111-1111-1111-1111-111111111111")
        #expect(shown.params == ["title": .string("Сториз 1")])
        #expect(host.sent.isEmpty)

        host.finishShow(.success(()))

        let response = try #require(host.sent.first)
        #expect(response.type == .response)
        #expect(response.payload == .object(["success": .bool(true)]))
        #expect(response.id == message.id)
        #expect(host.sent.count == 1)
    }

    @Test("Only the id is required")
    func onlyIdIsRequired() throws {
        let host = InappRequestHostSpy()

        ShowInAppActionHandler().handle(.request(.showInApp, payload: .object(["inappId": .string("some-id")])),
                                        host: host)

        let shown = try #require(host.shown.first)
        #expect(shown.id == "some-id")
        #expect(shown.params.isEmpty)
    }

    @Test("A show that did not happen is refused with the contract's reason",
          arguments: [ShowInAppRefusal.unknownInapp, .sourceDismissed, .showFailed])
    func refusedShowCarriesTheReason(refusal: ShowInAppRefusal) throws {
        let host = InappRequestHostSpy()
        let message = BridgeMessage.request(.showInApp, payload: .object(["inappId": .string("some-id")]))

        ShowInAppActionHandler().handle(message, host: host)
        host.finishShow(.failure(refusal))

        let response = try #require(host.sent.first)
        #expect(response.type == .error)
        #expect(response.id == message.id)
        #expect(response.payload == .object(["error": .string(refusal.rawValue)]))
    }

    @Test("A request without an id is refused", arguments: [
        JSONValue.object([:]),
        .object(["inappId": .string("")]),
        .object(["inappId": .int(1)])
    ])
    func missingIdIsRefused(payload: JSONValue) throws {
        let host = InappRequestHostSpy()

        ShowInAppActionHandler().handle(.request(.showInApp, payload: payload), host: host)

        #expect(host.shown.isEmpty)
        let response = try #require(host.sent.first)
        #expect(response.type == .error)
        #expect(response.payload == .object(["error": .string("Invalid payload: missing or empty 'inappId'")]))
    }

    @Test("A host without an in-app service refuses the request instead of keeping silent")
    func hostWithoutInappServiceRefuses() throws {
        let host = HostSpy()

        ShowInAppActionHandler().handle(.request(.showInApp, payload: .object(["inappId": .string("some-id")])),
                                        host: host)

        let response = try #require(host.sent.first)
        #expect(response.type == .error)
        #expect(response.payload == .object(["error": .string("showInApp is not served on this surface")]))
    }
}

private final class InappRequestHostSpy: HostSpy, WebBridgeInappRequestHosting {

    var allowed: [String] = []

    var isDeferred = false

    private(set) var askedIds: [[String]] = []
    private(set) var shown: [(id: String, params: [String: JSONValue])] = []

    private var pending: [([String]) -> Void] = []
    private var showCompletions: [(Result<Void, ShowInAppRefusal>) -> Void] = []

    func bridgeDidAskShowableInapps(_ ids: [String], completion: @escaping ([String]) -> Void) {
        askedIds.append(ids)

        if isDeferred {
            pending.append(completion)
        } else {
            completion(allowed)
        }
    }

    func bridgeDidRequestShowInApp(id: String,
                                   params: [String: JSONValue],
                                   completion: @escaping (Result<Void, ShowInAppRefusal>) -> Void) {
        shown.append((id, params))
        showCompletions.append(completion)
    }

    func finishShow(_ outcome: Result<Void, ShowInAppRefusal>) {
        let completions = showCompletions
        showCompletions = []
        completions.forEach { $0(outcome) }
    }

    func flush() {
        let completions = pending
        pending = []
        completions.forEach { $0(allowed) }
    }
}
