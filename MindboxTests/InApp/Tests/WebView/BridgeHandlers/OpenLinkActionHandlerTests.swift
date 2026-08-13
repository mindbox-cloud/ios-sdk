//
//  OpenLinkActionHandlerTests.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
@_spi(Internal) @testable import Mindbox

@Suite("OpenLinkActionHandler", .tags(.webView))
@MainActor
struct OpenLinkActionHandlerTests {

    @Test("Owns the openLink action")
    func ownsOpenLink() {
        #expect(OpenLinkActionHandler().actions == [.openLink])
    }

    // MARK: - Routing by scheme

    /// A web address may belong to an installed app, so the system is asked first and only
    /// falls back to opening it in-app.
    @Test("A web address is offered as a universal link first", arguments: ["https://example.com", "http://example.com"])
    func webAddressTriesUniversalLinkFirst(urlString: String) async {
        let opener = URLOpenerSpy()
        let host = HostSpy()

        let handler = OpenLinkActionHandler(urlOpener: opener)

        handler.handle(.request(.openLink, payload: .object(["url": .string(urlString)])), host: host)
        await drainMainQueue(until: { !opener.opened.isEmpty })

        #expect(opener.opened.first?.universalLinksOnly == true)
    }

    /// Anything that is not a web address means nothing to Safari — only the system knows
    /// which app answers `tel:` or a deep link.
    @Test("A non-web scheme goes straight to the system",
          arguments: ["tel:+123456789", "mailto:a@b.c", "myapp://product/1"])
    func otherSchemesGoToSystem(urlString: String) async {
        let opener = URLOpenerSpy()
        let host = HostSpy()

        let handler = OpenLinkActionHandler(urlOpener: opener)

        handler.handle(.request(.openLink, payload: .object(["url": .string(urlString)])), host: host)
        await drainMainQueue(until: { !opener.opened.isEmpty })

        #expect(opener.opened.first?.universalLinksOnly == false)
    }

    // MARK: - Outcomes

    @Test("An opened universal link is reported as a success")
    func universalLinkSuccessIsReported() async throws {
        let opener = URLOpenerSpy()
        opener.result = true
        let host = HostSpy()

        let handler = OpenLinkActionHandler(urlOpener: opener)

        handler.handle(.request(.openLink, payload: .object(["url": .string("https://example.com")])), host: host)
        await drainMainQueue(until: { !host.sent.isEmpty })

        let response = try #require(host.sent.first)
        #expect(response.type == .response)
        #expect(response.payload == .object(["success": .bool(true)]))
    }

    @Test("A system open that fails is reported as an error")
    func systemFailureIsReported() async throws {
        let opener = URLOpenerSpy()
        opener.result = false
        let host = HostSpy()

        let handler = OpenLinkActionHandler(urlOpener: opener)

        handler.handle(.request(.openLink, payload: .object(["url": .string("myapp://nope")])), host: host)
        await drainMainQueue(until: { !host.sent.isEmpty })

        let response = try #require(host.sent.first)
        #expect(response.type == .error)
        #expect(response.payload == .object(["error": .string("Failed to open URL: 'myapp://nope'")]))
    }

    // MARK: - Refusals

    @Test("A missing url is refused without reaching the system")
    func missingURLIsRefused() throws {
        let opener = URLOpenerSpy()
        let host = HostSpy()

        let handler = OpenLinkActionHandler(urlOpener: opener)

        handler.handle(.request(.openLink, payload: .object([:])), host: host)

        #expect(opener.opened.isEmpty)
        let response = try #require(host.sent.first)
        #expect(response.type == .error)
        #expect(response.payload == .object(["error": .string("Invalid payload: missing or empty 'url' field")]))
    }

    @Test("An empty url is refused")
    func emptyURLIsRefused() throws {
        let host = HostSpy()

        let handler = OpenLinkActionHandler(urlOpener: URLOpenerSpy())

        handler.handle(.request(.openLink, payload: .object(["url": .string("")])), host: host)

        #expect(host.sent.first?.type == .error)
    }

    @Test("A payload sent as a JSON string is understood too")
    func acceptsStringifiedPayload() async {
        let opener = URLOpenerSpy()
        let host = HostSpy()

        let handler = OpenLinkActionHandler(urlOpener: opener)

        handler.handle(.request(.openLink, payload: .string("{\"url\":\"https://example.com\"}")), host: host)
        await drainMainQueue(until: { !opener.opened.isEmpty })

        #expect(opener.opened.count == 1)
    }

    @Test("The answer carries the id of the request it answers")
    func answerKeepsRequestIdentity() async throws {
        let opener = URLOpenerSpy()
        opener.result = true
        let host = HostSpy()
        let message = BridgeMessage.request(.openLink, payload: .object(["url": .string("myapp://x")]))

        let handler = OpenLinkActionHandler(urlOpener: opener)

        handler.handle(message, host: host)
        await drainMainQueue(until: { !host.sent.isEmpty })

        #expect(host.sent.first?.id == message.id)
    }
}

// MARK: - Doubles

final class URLOpenerSpy: BridgeURLOpening {

    var result = false

    private(set) var opened: [(url: URL, universalLinksOnly: Bool)] = []

    func open(_ url: URL, universalLinksOnly: Bool, completion: @escaping (Bool) -> Void) {
        opened.append((url, universalLinksOnly))
        completion(result)
    }
}
