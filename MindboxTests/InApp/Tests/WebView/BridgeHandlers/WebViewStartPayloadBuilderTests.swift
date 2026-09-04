//
//  WebViewStartPayloadBuilderTests.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import UIKit
import UserNotifications
@_spi(Internal) @testable import Mindbox

/// Pins what a page is told at start-up.
///
/// The payload was assembled inside the WebView facade and moved out wholesale; the failure to
/// guard against is a field quietly going missing on the way, which no other suite would see —
/// the page would simply configure itself wrong.
@Suite("WebViewStartPayloadBuilder", .tags(.webView))
@MainActor
struct WebViewStartPayloadBuilderTests {

    init() {
        TestConfiguration.configure()
    }

    private func build(contentId: String = "content-1",
                       operation: (name: String, body: String)? = nil,
                       customParams: [String: JSONValue]? = nil) async throws -> [String: JSONValue] {
        let builder = WebViewStartPayloadBuilder(contentId: contentId,
                                                 operation: operation,
                                                 customParams: customParams,
                                                 insetsSource: UIView(),
                                                 logError: { _ in })
        let payload = await withCheckedContinuation { continuation in
            builder.build { continuation.resume(returning: $0) }
        }

        // The contract has JS calling JSON.parse on it, so a string is the shape, not a detail.
        guard case .string(let json) = payload else {
            throw BuilderTestError.payloadIsNotAString
        }

        let data = try #require(json.data(using: .utf8))
        return try JSONDecoder().decode([String: JSONValue].self, from: data)
    }

    private func object(_ value: JSONValue?) throws -> [String: JSONValue] {
        guard case .object(let dictionary)? = value else {
            throw BuilderTestError.valueIsNotAnObject
        }
        return dictionary
    }

    /// The test container answers `.authorized` for notifications by default; this swaps in another
    /// answer for the duration of `body` and rebuilds the container afterwards.
    private func withNotificationAuthorization<T>(_ status: UNAuthorizationStatus,
                                                  _ body: () async throws -> T) async throws -> T {
        let base = MBInject.buildTestContainer
        defer {
            MBInject.buildTestContainer = base
            MBInject.mode = .test
        }
        MBInject.buildTestContainer = {
            let container = base()
            container.register(UNAuthorizationStatusProviding.self, scope: .transient) {
                MockUNAuthorizationStatusProvider(status: status)
            }
            return container
        }
        MBInject.mode = .test

        return try await body()
    }

    @Test("Always carries the fields a page cannot configure itself without")
    func carriesRequiredFields() async throws {
        let payload = try await build()

        for key in ["sdkVersion", "sdkVersionNumeric", "endpointId", "deviceUUID",
                    "userVisitCount", "inappId", "localStateVersion", "insets", "permissions"] {
            #expect(payload[key] != nil, "'\(key)' is missing from the start payload")
        }
    }

    /// The backend's spelling, and the one every other bridge payload already uses. Safe only in
    /// this order: the page that reads `inappId` and falls back to `inAppId` ships before this SDK.
    @Test("The content id travels as inappId, not the old inAppId")
    func contentIdTravelsAsInappId() async throws {
        let payload = try await build(contentId: "block-42")

        #expect(payload["inappId"] == .string("block-42"))
        #expect(payload["inAppId"] == nil)
    }

    @Test("Insets are reported as four named edges")
    func insetsAreNamedEdges() async throws {
        let payload = try await build()

        let insets = try object(payload["insets"])

        #expect(Set(insets.keys) == ["top", "left", "bottom", "right"])
    }

    // MARK: - Permissions

    /// In sync with Android: the key is always there, so a page reads one shape whether or not
    /// anything is granted. Only notifications are under the test's control — the camera and the
    /// rest are asked of the simulator as they are.
    @Test("permissions is present even when notifications are not granted")
    func permissionsIsPresentWhenNotificationsAreNotGranted() async throws {
        try await withNotificationAuthorization(.denied) {
            let payload = try await build()

            let permissions = try object(payload["permissions"])
            #expect(permissions["notifications"] == nil)
        }
    }

    @Test("A granted permission travels as an object with a status")
    func grantedPermissionTravelsAsStatusObject() async throws {
        let payload = try await build()

        let permissions = try object(payload["permissions"])
        #expect(permissions["notifications"] == .object(["status": .string("granted")]))
    }

    /// The stored flag is refreshed only when the app comes to the foreground; a permission the
    /// user grants from a page would stay invisible to the next page until then.
    @Test("The notifications status is asked of the system, not read from the stored flag")
    func notificationsStatusIsAskedLive() async throws {
        let storage = DI.injectOrFail(PersistenceStorage.self)
        storage.isNotificationsEnabled = false

        let payload = try await build()

        let permissions = try object(payload["permissions"])
        #expect(permissions["notifications"] == .object(["status": .string("granted")]))
    }

    @Test("The operation is included only when there is one")
    func operationIsOptional() async throws {
        let without = try await build()
        #expect(without["operationName"] == nil)
        #expect(without["operationBody"] == nil)

        let with = try await build(operation: (name: "Test.Operation", body: #"{"a":1}"#))
        #expect(with["operationName"] == .string("Test.Operation"))
        #expect(with["operationBody"] == .string(#"{"a":1}"#))
    }

    @Test("Configuration params are merged at the root, not nested")
    func customParamsMergeAtRoot() async throws {
        let payload = try await build(customParams: ["catalogEntry": .string("stories-feed")])

        #expect(payload["catalogEntry"] == .string("stories-feed"))
    }

    /// The order the fields are applied in is load-bearing: the configuration's own params are
    /// merged before the operation, so a collision resolves towards the operation.
    @Test("A configuration param cannot displace the operation")
    func operationWinsOverCustomParams() async throws {
        let payload = try await build(operation: (name: "Real.Operation", body: "{}"),
                                      customParams: ["operationName": .string("from-config")])

        #expect(payload["operationName"] == .string("Real.Operation"))
    }

    // MARK: - Who wins a collision

    /// Deliberate: a direct call names what this show must carry, so its params outrank the fields
    /// the SDK fills in. Pinned so the day someone protects these keys is a decision, not a slip.
    @Test("A param can displace a field the SDK fills in", arguments: [
        "deviceUUID", "endpointId", "inappId", "sdkVersion", "userVisitCount", "localStateVersion", "permissions"
    ])
    func customParamsDisplaceSdkFields(key: String) async throws {
        let untouched = try await build()
        #expect(untouched[key] != nil, "the field has to be there for the override to mean anything")

        let payload = try await build(customParams: [key: .string("from-the-page")])

        #expect(payload[key] == .string("from-the-page"))
    }

    @Test("A param cannot displace the track-visit fields")
    func trackVisitWinsOverCustomParams() async throws {
        let previous = SessionTemporaryStorage.shared.lastTrackVisit
        defer { SessionTemporaryStorage.shared.lastTrackVisit = previous }
        SessionTemporaryStorage.shared.lastTrackVisit = (source: .push, requestUrl: "https://real.visit")

        let payload = try await build(customParams: [
            "trackVisitSource": .string("from-config"),
            "trackVisitRequestUrl": .string("https://from-config")
        ])

        #expect(payload["trackVisitSource"] == .string(TrackVisitSource.push.rawValue))
        #expect(payload["trackVisitRequestUrl"] == .string("https://real.visit"))
    }

    @Test("On a collision the caller's params beat the configuration's")
    func callerParamsBeatTheConfiguration() {
        let merged = WebViewStartPayloadBuilder.mergedParams(
            config: ["shared": .string("from-config"), "onlyInConfig": .string("kept")],
            fromCaller: ["shared": .string("from-the-page"), "onlyFromCaller": .string("added")]
        )

        #expect(merged["shared"] == .string("from-the-page"))
        #expect(merged["onlyInConfig"] == .string("kept"))
        #expect(merged["onlyFromCaller"] == .string("added"))
    }

    @Test("A show with no params of its own carries the configuration's untouched")
    func noCallerParamsKeepsTheConfiguration() {
        let config: [String: JSONValue] = ["catalogEntry": .string("stories-feed")]

        #expect(WebViewStartPayloadBuilder.mergedParams(config: config, fromCaller: nil) == config)
    }

    /// A page that receives `{}` reports its own failure; a page that receives nothing waits on
    /// an id that will never be closed.
    @Test("An unencodable payload degrades to an empty object rather than to silence")
    func unencodablePayloadDegradesToEmptyObject() async {
        let reported = Reported()
        let builder = WebViewStartPayloadBuilder(contentId: "content-1",
                                                 operation: nil,
                                                 // Not representable in JSON.
                                                 customParams: ["bad": .double(.nan)],
                                                 insetsSource: nil,
                                                 logError: { reported.messages.append($0) })

        let payload = await withCheckedContinuation { continuation in
            builder.build { continuation.resume(returning: $0) }
        }

        #expect(payload == .string("{}"))
        #expect(reported.messages.count == 1)
    }
}

private final class Reported {
    var messages: [String] = []
}

private enum BuilderTestError: Error {
    case payloadIsNotAString
    case valueIsNotAnObject
}
