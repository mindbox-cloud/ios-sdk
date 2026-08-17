//
//  HapticActionHandlerTests.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
@_spi(Internal) @testable import Mindbox

@Suite("HapticActionHandler", .tags(.webView))
struct HapticActionHandlerTests {

    private func makeSUT() -> (handler: HapticActionHandler, service: HapticServiceSpy, host: HostSpy) {
        let service = HapticServiceSpy()
        return (HapticActionHandler(makeService: { service }), service, HostSpy())
    }

    @Test("Owns the haptic action")
    func ownsHaptic() {
        #expect(HapticActionHandler().actions == [.haptic])
    }

    @Test("The request is handed to the engine and confirmed")
    func requestReachesEngine() throws {
        let (handler, service, host) = makeSUT()
        let message = BridgeMessage.request(.haptic, payload: .object(["type": .string("selection")]))

        handler.handle(message, host: host)

        #expect(service.handled.count == 1)
        let response = try #require(host.sent.first)
        #expect(response.type == .response)
        #expect(response.payload == .object(["success": .bool(true)]))
        #expect(response.id == message.id)
    }

    /// The engine is warmed up when the page reports it is up, so the first tap does not pay
    /// for starting it.
    @Test("Preparing warms the engine")
    func prepareWarmsEngine() {
        let (handler, service, _) = makeSUT()

        handler.prepare()

        #expect(service.prepareCount == 1)
    }

    @Test("Teardown stops a pattern once the engine was in use")
    func tearDownStopsPattern() {
        let (handler, service, host) = makeSUT()
        handler.handle(.request(.haptic, payload: .object(["type": .string("selection")])), host: host)

        handler.tearDown()

        #expect(service.stopCount == 1)
    }

    /// Every show ends, and most never buzz: teardown must not be what builds an engine.
    @Test("Teardown builds no engine when haptics were never used")
    func tearDownBuildsNothingWhenUnused() {
        var built = 0
        let handler = HapticActionHandler(makeService: {
            built += 1
            return HapticServiceSpy()
        })

        handler.tearDown()

        #expect(built == 0)
    }

    /// The service is registered transient, so a second resolution would be a second engine —
    /// preparing one while playing on another silently does nothing.
    @Test("One engine serves preparing, playing and stopping")
    func oneEngineThroughout() {
        var built = 0
        let service = HapticServiceSpy()
        let handler = HapticActionHandler(makeService: { built += 1; return service })

        handler.prepare()
        handler.handle(.request(.haptic, payload: .object(["type": .string("selection")])), host: HostSpy())
        handler.tearDown()

        #expect(built == 1)
        #expect(service.prepareCount == 1)
        #expect(service.handled.count == 1)
        #expect(service.stopCount == 1)
    }
}

// MARK: - Doubles

final class HapticServiceSpy: HapticServiceProtocol {

    private(set) var prepareCount = 0
    private(set) var stopCount = 0
    private(set) var handled: [BridgeMessage] = []

    func prepare() {
        prepareCount += 1
    }

    func stopPattern() {
        stopCount += 1
    }

    func handle(message: BridgeMessage) {
        handled.append(message)
    }
}
