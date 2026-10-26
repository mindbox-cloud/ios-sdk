//
//  PermissionActionHandlerTests.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
@_spi(Internal) @testable import Mindbox

@Suite("PermissionActionHandler", .tags(.webView))
@MainActor
struct PermissionActionHandlerTests {

    private func makeSUT(result: PermissionRequestResult = .granted(dialogShown: true),
                         requiredKeys: [String] = [],
                         presentKeys: Set<String> = [],
                         registered: Bool = true)
    -> (handler: PermissionActionHandler, permission: PermissionHandlerSpy, host: HostSpy) {
        let permission = PermissionHandlerSpy(result: result, requiredInfoPlistKeys: requiredKeys)
        let registry = PermissionRegistrySpy(handler: registered ? permission : nil)
        let handler = PermissionActionHandler(makeRegistry: { registry },
                                              infoPlistValue: { presentKeys.contains($0) ? "value" : nil })
        return (handler, permission, HostSpy())
    }

    private func pushRequest() -> BridgeMessage {
        .request(.permissionRequest, payload: .object(["type": .string("pushNotifications")]))
    }

    @Test("Owns the permission.request action")
    func ownsPermissionRequest() {
        #expect(PermissionActionHandler().actions == [.permissionRequest])
    }

    // MARK: - Outcomes

    @Test("A grant answers with the result and whether a dialog was shown")
    func grantIsReported() async throws {
        let (handler, _, host) = makeSUT(result: .granted(dialogShown: true))

        handler.handle(pushRequest(), host: host)
        await drainMainQueue(until: { !host.sent.isEmpty })

        let response = try #require(host.sent.first)
        #expect(response.type == .response)
        #expect(response.payload == .object(["result": .string("granted"), "dialogShown": .bool(true)]))
    }

    @Test("A standing refusal answers denied without a dialog")
    func standingDenialIsReported() async throws {
        let (handler, _, host) = makeSUT(result: .denied(dialogShown: false))

        handler.handle(pushRequest(), host: host)
        await drainMainQueue(until: { !host.sent.isEmpty })

        #expect(host.sent.first?.payload == .object(["result": .string("denied"), "dialogShown": .bool(false)]))
    }

    @Test("A failure from the permission handler reaches the page as an error")
    func handlerErrorIsReported() async throws {
        let (handler, _, host) = makeSUT(result: .error("Something went wrong"))

        handler.handle(pushRequest(), host: host)
        await drainMainQueue(until: { !host.sent.isEmpty })

        let response = try #require(host.sent.first)
        #expect(response.type == .error)
        #expect(response.payload == .object(["error": .string("permission_failed")]))
    }

    // MARK: - Refusals

    @Test("A missing type is refused")
    func missingTypeIsRefused() throws {
        let (handler, permission, host) = makeSUT()

        handler.handle(.request(.permissionRequest, payload: .object([:])), host: host)

        #expect(permission.requestCount == 0)
        #expect(host.sent.first?.payload == .object(["error": .string("invalid_payload")]))
    }

    @Test("A permission the SDK does not know is refused as an unsupported value", arguments: ["camera", " "])
    func unknownTypeIsRefused(type: String) throws {
        let (handler, permission, host) = makeSUT()

        handler.handle(.request(.permissionRequest, payload: .object(["type": .string(type)])), host: host)

        #expect(permission.requestCount == 0)
        #expect(host.sent.first?.payload == .object(["error": .string("unsupported_value")]))
    }

    @Test("A known permission with no handler registered is refused")
    func unregisteredTypeIsRefused() throws {
        let (handler, _, host) = makeSUT(registered: false)

        handler.handle(pushRequest(), host: host)

        #expect(host.sent.first?.payload == .object(["error": .string("internal_error")]))
    }

    @Test("A missing Info.plist key is reported and the permission is never requested")
    func missingInfoPlistKeyIsRefused() throws {
        let (handler, permission, host) = makeSUT(requiredKeys: ["NSUserTrackingUsageDescription"])

        handler.handle(pushRequest(), host: host)

        #expect(permission.requestCount == 0)
        #expect(host.sent.first?.payload == .object(["error": .string("permission_failed")]))
    }

    @Test("A required key that is present lets the request through")
    func presentInfoPlistKeyAllowsRequest() async {
        let (handler, permission, host) = makeSUT(requiredKeys: ["NSUserTrackingUsageDescription"],
                                                  presentKeys: ["NSUserTrackingUsageDescription"])

        handler.handle(pushRequest(), host: host)
        await drainMainQueue(until: { permission.requestCount > 0 })

        #expect(permission.requestCount == 1)
    }

    @Test("A payload sent as a JSON string is understood too")
    func acceptsStringifiedPayload() async {
        let (handler, permission, host) = makeSUT()

        handler.handle(.request(.permissionRequest, payload: .string("{\"type\":\"pushNotifications\"}")), host: host)
        await drainMainQueue(until: { permission.requestCount > 0 })

        #expect(permission.requestCount == 1)
    }

    // MARK: - Lifetime

    @Test("A page released while the dialog is up is not held by the pending request")
    func pendingRequestDoesNotHoldPage() async {
        let permission = PermissionHandlerSpy(result: .granted(dialogShown: true),
                                              requiredInfoPlistKeys: [],
                                              defersAnswer: true)
        let registry = PermissionRegistrySpy(handler: permission)
        let handler = PermissionActionHandler(makeRegistry: { registry }, infoPlistValue: { _ in "value" })

        weak var page: HostSpy?

        do {
            let host = HostSpy()
            page = host
            handler.handle(pushRequest(), host: host)
            #expect(permission.requestCount == 1)
        }

        #expect(page == nil)
    }

    @Test("An answer that arrives after the page is gone is dropped")
    func lateAnswerIsDropped() async {
        let permission = PermissionHandlerSpy(result: .granted(dialogShown: true),
                                              requiredInfoPlistKeys: [],
                                              defersAnswer: true)
        let registry = PermissionRegistrySpy(handler: permission)
        let handler = PermissionActionHandler(makeRegistry: { registry }, infoPlistValue: { _ in "value" })

        var host: HostSpy? = HostSpy()
        handler.handle(pushRequest(), host: host!)
        host = nil

        permission.answer()
        await drainMainQueue(until: { false }, turns: 3)
    }
}

// MARK: - Doubles

final class PermissionHandlerSpy: PermissionHandler {

    let permissionType: PermissionType = .pushNotifications
    let requiredInfoPlistKeys: [String]

    private let result: PermissionRequestResult

    private let defersAnswer: Bool

    private var pendingAnswer: ((PermissionRequestResult) -> Void)?

    private(set) var requestCount = 0

    init(result: PermissionRequestResult, requiredInfoPlistKeys: [String], defersAnswer: Bool = false) {
        self.result = result
        self.requiredInfoPlistKeys = requiredInfoPlistKeys
        self.defersAnswer = defersAnswer
    }

    func request(completion: @escaping (PermissionRequestResult) -> Void) {
        requestCount += 1

        guard defersAnswer else {
            completion(result)
            return
        }

        pendingAnswer = completion
    }

    func answer() {
        let pendingAnswer = self.pendingAnswer
        self.pendingAnswer = nil
        pendingAnswer?(result)
    }
}

final class PermissionRegistrySpy: PermissionHandlerRegistryProtocol {

    private let stub: PermissionHandler?

    init(handler: PermissionHandler?) {
        self.stub = handler
    }

    func handler(for type: PermissionType) -> PermissionHandler? {
        stub
    }
}
