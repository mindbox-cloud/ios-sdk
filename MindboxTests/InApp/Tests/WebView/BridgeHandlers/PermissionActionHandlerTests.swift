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

    /// The page is told both the stance and whether a dialog appeared, so it can tell a fresh
    /// refusal from a standing one.
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
        #expect(response.payload == .object(["error": .string("Something went wrong")]))
    }

    // MARK: - Refusals

    @Test("A missing type is refused")
    func missingTypeIsRefused() throws {
        let (handler, permission, host) = makeSUT()

        handler.handle(.request(.permissionRequest, payload: .object([:])), host: host)

        #expect(permission.requestCount == 0)
        #expect(host.sent.first?.payload == .object(["error": .string("Invalid payload: missing or empty 'type' field")]))
    }

    @Test("A permission the SDK does not know is refused by name")
    func unknownTypeIsRefused() throws {
        let (handler, permission, host) = makeSUT()

        handler.handle(.request(.permissionRequest, payload: .object(["type": .string("camera")])), host: host)

        #expect(permission.requestCount == 0)
        #expect(host.sent.first?.payload == .object(["error": .string("Unknown permission type: 'camera'")]))
    }

    @Test("A known permission with no handler registered is refused")
    func unregisteredTypeIsRefused() throws {
        let (handler, _, host) = makeSUT(registered: false)

        handler.handle(pushRequest(), host: host)

        #expect(host.sent.first?.payload
                == .object(["error": .string("No handler registered for permission type: 'pushNotifications'")]))
    }

    /// Asking without the usage description in place would kill the host app rather than
    /// return a refusal, so the missing key is reported instead of requested.
    @Test("A missing Info.plist key is reported and the permission is never requested")
    func missingInfoPlistKeyIsRefused() throws {
        let (handler, permission, host) = makeSUT(requiredKeys: ["NSUserTrackingUsageDescription"])

        handler.handle(pushRequest(), host: host)

        #expect(permission.requestCount == 0)
        #expect(host.sent.first?.payload
                == .object(["error": .string("Missing Info.plist key: NSUserTrackingUsageDescription")]))
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
}

// MARK: - Doubles

final class PermissionHandlerSpy: PermissionHandler {

    let permissionType: PermissionType = .pushNotifications
    let requiredInfoPlistKeys: [String]

    private let result: PermissionRequestResult

    private(set) var requestCount = 0

    init(result: PermissionRequestResult, requiredInfoPlistKeys: [String]) {
        self.result = result
        self.requiredInfoPlistKeys = requiredInfoPlistKeys
    }

    func request(completion: @escaping (PermissionRequestResult) -> Void) {
        requestCount += 1
        completion(result)
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
