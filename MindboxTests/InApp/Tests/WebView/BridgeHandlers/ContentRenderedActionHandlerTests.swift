//
//  ContentRenderedActionHandlerTests.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import UIKit
import MindboxLogger
@_spi(Internal) @testable import Mindbox

@Suite("ContentRenderedActionHandler", .tags(.webView))
struct ContentRenderedActionHandlerTests {

    @Test("Owns the contentRendered action")
    func ownsContentRendered() {
        #expect(ContentRenderedActionHandler().actions == [.contentRendered])
    }

    @Test("A count reaches the host and is confirmed")
    func countReachesHost() throws {
        let host = ContentHostSpy()
        let message = BridgeMessage.request(.contentRendered, payload: .object(["count": .int(5)]))

        ContentRenderedActionHandler().handle(message, host: host)

        #expect(host.rendered == [5])
        let response = try #require(host.sent.first)
        #expect(response.type == .response)
        #expect(response.id == message.id)
    }

    /// Alive, correct, and with nothing to show. The handler passes it on as an outcome rather
    /// than turning it into an error — deciding what to do with it belongs to the surface.
    @Test("Zero is delivered like any other count")
    func zeroIsDelivered() {
        let host = ContentHostSpy()

        ContentRenderedActionHandler().handle(.request(.contentRendered, payload: .object(["count": .int(0)])),
                                              host: host)

        #expect(host.rendered == [0])
        #expect(host.sent.first?.type == .response)
    }

    /// JS has one number type, so a whole value may arrive either way.
    @Test("A count sent as a JS number is understood")
    func doubleCountIsUnderstood() {
        let host = ContentHostSpy()

        ContentRenderedActionHandler().handle(.request(.contentRendered, payload: .object(["count": .double(3)])),
                                              host: host)

        #expect(host.rendered == [3])
    }

    @Test("A payload sent as a JSON string is understood too")
    func acceptsStringifiedPayload() {
        let host = ContentHostSpy()

        ContentRenderedActionHandler().handle(.request(.contentRendered, payload: .string(#"{"count":2}"#)),
                                              host: host)

        #expect(host.rendered == [2])
    }

    /// Deferred precisely so this can be refused: the blanket success would claim the SDK acted
    /// on a number it never received.
    @Test("A payload without a usable count is refused and never reaches the host")
    func missingCountIsRefused() throws {
        let host = ContentHostSpy()

        ContentRenderedActionHandler().handle(.request(.contentRendered, payload: .object([:])), host: host)

        #expect(host.rendered.isEmpty)
        let response = try #require(host.sent.first)
        #expect(response.type == .error)
        #expect(response.payload == .object(["error": .string("Invalid payload: missing or non-numeric 'count'")]))
    }

    @Test("A non-numeric count is refused")
    func nonNumericCountIsRefused() {
        let host = ContentHostSpy()

        ContentRenderedActionHandler().handle(.request(.contentRendered, payload: .object(["count": .string("many")])),
                                              host: host)

        #expect(host.rendered.isEmpty)
        #expect(host.sent.first?.type == .error)
    }

    /// A whole number of items or nothing. Rounding would take a page bug and turn it into a
    /// plausible number the SDK then acts on.
    @Test("A fractional count is refused rather than rounded")
    func fractionalCountIsRefused() throws {
        let host = ContentHostSpy()

        ContentRenderedActionHandler().handle(.request(.contentRendered, payload: .object(["count": .double(3.6)])),
                                              host: host)

        #expect(host.rendered.isEmpty)
        let response = try #require(host.sent.first)
        #expect(response.type == .error)
        #expect(response.payload == .object(["error": .string("Invalid payload: 'count' must be a whole number, got 3.6")]))
    }

    /// The reason it is worth refusing at all: rounding decides the block's fate on the page's
    /// behalf. `0.4` would reach the host as `0` and collapse the block as empty, `0.6` as `1` and
    /// show it — the same page bug, two opposite outcomes, neither of them reported.
    @Test("A fraction either side of a half is refused, not turned into a verdict",
          arguments: [0.4, 0.6, 1.5, 2.9])
    func fractionNeverBecomesAVerdict(count: Double) {
        let host = ContentHostSpy()

        ContentRenderedActionHandler().handle(.request(.contentRendered, payload: .object(["count": .double(count)])),
                                              host: host)

        #expect(host.rendered.isEmpty)
        #expect(host.sent.first?.type == .error)
    }

    /// Not numbers of items either, and `Int(exactly:)` turns them away with the fractions.
    @Test("A count that is not a finite number is refused",
          arguments: [Double.nan, .infinity, -.infinity, 1e30])
    func unusableNumberIsRefused(count: Double) {
        let host = ContentHostSpy()

        ContentRenderedActionHandler().handle(.request(.contentRendered, payload: .object(["count": .double(count)])),
                                              host: host)

        #expect(host.rendered.isEmpty)
        #expect(host.sent.first?.type == .error)
    }

    @Test("A negative count is refused rather than clamped")
    func negativeCountIsRefused() {
        let host = ContentHostSpy()

        ContentRenderedActionHandler().handle(.request(.contentRendered, payload: .object(["count": .int(-1)])),
                                              host: host)

        #expect(host.rendered.isEmpty)
        #expect(host.sent.first?.payload
                == .object(["error": .string("Invalid payload: 'count' must not be negative, got -1")]))
    }

    /// The action is registered on every surface. One that reserves no space for content simply
    /// does not listen — the report is journalled and acknowledged, never refused, so a page can
    /// send it wherever it lives.
    @Test("A host that listens for no content acknowledges anyway")
    func hostWithoutCapabilityAcknowledges() throws {
        let host = HostSpy()

        ContentRenderedActionHandler().handle(.request(.contentRendered, payload: .object(["count": .int(4)])),
                                              host: host)

        let response = try #require(host.sent.first)
        #expect(response.type == .response)
        #expect(response.payload == .object(["success": .bool(true)]))
    }
}

// MARK: - Doubles

private final class ContentHostSpy: WebBridgeHost, WebBridgeContentHosting {

    var contentId = "test-content-id"
    var logCategory: LogCategory = .embeddedBlocks
    var tags: [String: String]?
    var presentingViewController: UIViewController? { nil }
    var isUserPresent = true

    private(set) var sent: [BridgeMessage] = []
    private(set) var rendered: [Int] = []

    func send(_ message: BridgeMessage) {
        sent.append(message)
    }

    func makeStartPayload() -> JSONValue {
        .string("{}")
    }

    func bridgeDidRenderContent(count: Int) {
        rendered.append(count)
    }
}
