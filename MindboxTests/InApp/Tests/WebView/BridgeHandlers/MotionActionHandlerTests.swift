//
//  MotionActionHandlerTests.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
@_spi(Internal) @testable import Mindbox

@Suite("MotionActionHandler", .tags(.webView))
@MainActor
struct MotionActionHandlerTests {

    private func makeSUT(started: Set<MotionGesture> = [.shake],
                         unavailable: Set<MotionGesture> = [])
    -> (handler: MotionActionHandler, service: MotionServiceSpy, host: HostSpy) {
        let service = MotionServiceSpy(result: MotionStartResult(started: started, unavailable: unavailable))
        return (MotionActionHandler(makeService: { service }), service, HostSpy())
    }

    private func startRequest(_ gestures: [String]) -> BridgeMessage {
        .request(.motionStart, payload: .object(["gestures": .array(gestures.map { .string($0) })]))
    }

    @Test("Owns both motion actions")
    func ownsMotionActions() {
        #expect(MotionActionHandler().actions == [.motionStart, .motionStop])
    }

    // MARK: - Starting

    @Test("Requested gestures are passed to the service and confirmed")
    func startsRequestedGestures() throws {
        let (handler, service, host) = makeSUT(started: [.shake, .flip])

        handler.handle(startRequest(["shake", "flip"]), host: host)

        #expect(service.started == [.shake, .flip])
        #expect(host.sent.first?.payload == .object(["success": .bool(true)]))
    }

    /// A partial start is still a start: the page is told what it will not get rather than
    /// being refused everything it asked for.
    @Test("A partial start succeeds and names what is unavailable")
    func partialStartNamesUnavailable() throws {
        let (handler, _, host) = makeSUT(started: [.shake], unavailable: [.flip])

        handler.handle(startRequest(["shake", "flip"]), host: host)

        let response = try #require(host.sent.first)
        #expect(response.type == .response)
        #expect(response.payload == .object([
            "success": .bool(true),
            "unavailable": .array([.string("flip")])
        ]))
    }

    @Test("A start where nothing is available is an error")
    func fullyUnavailableStartIsAnError() throws {
        let (handler, _, host) = makeSUT(started: [], unavailable: [.flip])

        handler.handle(startRequest(["flip"]), host: host)

        let response = try #require(host.sent.first)
        #expect(response.type == .error)
        #expect(response.payload == .object(["error": .string("No sensors available for requested gestures: flip")]))
    }

    @Test("Unknown gesture names are dropped, and asking only for those is refused")
    func unknownGesturesAreRefused() throws {
        let (handler, service, host) = makeSUT()

        handler.handle(startRequest(["somersault"]), host: host)

        #expect(service.started == nil)
        #expect(host.sent.first?.payload
                == .object(["error": .string("No valid gestures provided. Available: shake, flip")]))
    }

    @Test("A payload without gestures is refused")
    func missingGesturesIsRefused() throws {
        let (handler, service, host) = makeSUT()

        handler.handle(.request(.motionStart, payload: .object([:])), host: host)

        #expect(service.started == nil)
        #expect(host.sent.first?.payload == .object(["error": .string("Invalid payload: 'gestures' must be an array")]))
    }

    /// The first guard has its own wording, because there is a difference worth telling the page:
    /// nothing arrived at all, as against something arrived in the wrong shape.
    @Test("A request with no payload at all is refused before the shape is looked at")
    func missingPayloadIsRefused() throws {
        let (handler, service, host) = makeSUT()

        handler.handle(.request(.motionStart), host: host)

        #expect(service.started == nil)
        #expect(host.sent.first?.payload == .object(["error": .string("Invalid payload: missing 'gestures' array")]))
    }

    @Test("A payload that is not an object is refused the same way")
    func nonObjectPayloadIsRefused() throws {
        let (handler, service, host) = makeSUT()

        handler.handle(.request(.motionStart, payload: .array([.string("shake")])), host: host)

        #expect(service.started == nil)
        #expect(host.sent.first?.payload == .object(["error": .string("Invalid payload: missing 'gestures' array")]))
    }

    @Test("A gestures field that is not an array is refused")
    func nonArrayGesturesIsRefused() throws {
        let (handler, _, host) = makeSUT()

        handler.handle(.request(.motionStart, payload: .object(["gestures": .string("shake")])), host: host)

        #expect(host.sent.first?.payload == .object(["error": .string("Invalid payload: 'gestures' must be an array")]))
    }

    // MARK: - Stopping

    @Test("Stopping reaches the service and is confirmed")
    func stopIsConfirmed() {
        let (handler, service, host) = makeSUT()
        handler.handle(startRequest(["shake"]), host: host)

        handler.handle(.request(.motionStop), host: host)

        #expect(service.stopCount == 1)
        #expect(host.sent.last?.payload == .object(["success": .bool(true)]))
    }

    // MARK: - Events

    /// A gesture arrives from the sensors with no request behind it, so it is pushed as a
    /// request of its own rather than as an answer.
    @Test("A detected gesture is pushed to the page as a request")
    func detectedGestureIsPushed() throws {
        let (handler, service, host) = makeSUT()
        handler.handle(startRequest(["flip"]), host: host)

        service.emit(.flip, data: ["from": "portrait", "to": "faceDown"])

        let event = try #require(host.sent.last)
        #expect(event.type == .request)
        #expect(event.action == BridgeMessage.Action.motionEvent.rawValue)
        #expect(event.payload == .object([
            "gesture": .string("flip"),
            "from": .string("portrait"),
            "to": .string("faceDown")
        ]))
    }

    @Test("A system shake is forwarded to the service")
    func systemShakeIsForwarded() {
        let (handler, service, host) = makeSUT()
        handler.handle(startRequest(["shake"]), host: host)

        handler.handleSystemShake()

        #expect(service.systemShakeCount == 1)
    }

    /// The sensors were never asked for, so there is nothing to forward to — and building a
    /// service to tell it about a shake nobody subscribed to would be worse than ignoring it.
    @Test("A system shake before any subscription builds no service")
    func systemShakeWithoutSubscriptionIsIgnored() {
        let service = MotionServiceSpy(result: MotionStartResult(started: [.shake], unavailable: []))
        var built = 0
        let handler = MotionActionHandler(makeService: { built += 1; return service })

        handler.handleSystemShake()

        #expect(built == 0)
        #expect(service.systemShakeCount == 0)
    }

    // MARK: - Teardown

    @Test("Teardown stops monitoring once the sensors were in use")
    func tearDownStopsMonitoring() {
        let (handler, service, host) = makeSUT()
        handler.handle(startRequest(["shake"]), host: host)

        handler.tearDown()

        #expect(service.stopCount == 1)
    }

    /// Every show ends, and most never touch motion: teardown must not be what starts a
    /// service, only what stops one.
    @Test("Teardown builds no service when motion was never used")
    func tearDownBuildsNothingWhenUnused() {
        var built = 0
        let handler = MotionActionHandler(makeService: {
            built += 1
            return MotionServiceSpy(result: MotionStartResult(started: [], unavailable: []))
        })

        handler.tearDown()

        #expect(built == 0)
    }
}

// MARK: - Doubles

final class MotionServiceSpy: MotionServiceProtocol {

    var onGestureDetected: ((MotionGesture, [String: Any]) -> Void)?

    private let result: MotionStartResult

    private(set) var started: Set<MotionGesture>?
    private(set) var stopCount = 0
    private(set) var systemShakeCount = 0

    init(result: MotionStartResult) {
        self.result = result
    }

    func startMonitoring(gestures: Set<MotionGesture>) -> MotionStartResult {
        started = gestures
        return result
    }

    func stopMonitoring() {
        stopCount += 1
    }

    func handleSystemShake() {
        systemShakeCount += 1
    }

    func emit(_ gesture: MotionGesture, data: [String: Any]) {
        onGestureDetected?(gesture, data)
    }
}
