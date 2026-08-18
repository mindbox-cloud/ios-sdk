//
//  WebViewStartPayloadBuilderTests.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import UIKit
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
                       customParams: [String: JSONValue]? = nil) throws -> [String: JSONValue] {
        let payload = WebViewStartPayloadBuilder(contentId: contentId,
                                                 operation: operation,
                                                 customParams: customParams,
                                                 insetsSource: UIView(),
                                                 logError: { _ in }).build()

        // The contract has JS calling JSON.parse on it, so a string is the shape, not a detail.
        guard case .string(let json) = payload else {
            throw BuilderTestError.payloadIsNotAString
        }

        let data = try #require(json.data(using: .utf8))
        return try JSONDecoder().decode([String: JSONValue].self, from: data)
    }

    @Test("Always carries the fields a page cannot configure itself without")
    func carriesRequiredFields() throws {
        let payload = try build()

        for key in ["sdkVersion", "sdkVersionNumeric", "endpointId", "deviceUUID",
                    "userVisitCount", "inAppId", "localStateVersion", "insets"] {
            #expect(payload[key] != nil, "'\(key)' is missing from the start payload")
        }
    }

    @Test("The content id travels as inAppId — the key the contract already uses")
    func contentIdTravelsAsInAppId() throws {
        let payload = try build(contentId: "block-42")

        #expect(payload["inAppId"] == .string("block-42"))
    }

    @Test("Insets are reported as four named edges")
    func insetsAreNamedEdges() throws {
        let payload = try build()

        guard case .object(let insets)? = payload["insets"] else {
            throw BuilderTestError.insetsAreNotAnObject
        }

        #expect(Set(insets.keys) == ["top", "left", "bottom", "right"])
    }

    @Test("The operation is included only when there is one")
    func operationIsOptional() throws {
        let without = try build()
        #expect(without["operationName"] == nil)
        #expect(without["operationBody"] == nil)

        let with = try build(operation: (name: "Test.Operation", body: #"{"a":1}"#))
        #expect(with["operationName"] == .string("Test.Operation"))
        #expect(with["operationBody"] == .string(#"{"a":1}"#))
    }

    @Test("Configuration params are merged at the root, not nested")
    func customParamsMergeAtRoot() throws {
        let payload = try build(customParams: ["catalogEntry": .string("stories-feed")])

        #expect(payload["catalogEntry"] == .string("stories-feed"))
    }

    /// The order the fields are applied in is load-bearing: the configuration's own params are
    /// merged before the operation, so a collision resolves towards the operation.
    @Test("A configuration param cannot displace the operation")
    func operationWinsOverCustomParams() throws {
        let payload = try build(operation: (name: "Real.Operation", body: "{}"),
                                customParams: ["operationName": .string("from-config")])

        #expect(payload["operationName"] == .string("Real.Operation"))
    }

    // MARK: - Who wins a collision

    /// Deliberate: a direct call names what this show must carry, so its params outrank the fields
    /// the SDK fills in. Pinned so the day someone protects these keys is a decision, not a slip.
    @Test("A param can displace a field the SDK fills in", arguments: [
        "deviceUUID", "endpointId", "inAppId", "sdkVersion", "userVisitCount", "localStateVersion"
    ])
    func customParamsDisplaceSdkFields(key: String) throws {
        let untouched = try build()
        #expect(untouched[key] != nil, "the field has to be there for the override to mean anything")

        let payload = try build(customParams: [key: .string("from-the-page")])

        #expect(payload[key] == .string("from-the-page"))
    }

    @Test("A param cannot displace the track-visit fields")
    func trackVisitWinsOverCustomParams() throws {
        let previous = SessionTemporaryStorage.shared.lastTrackVisit
        defer { SessionTemporaryStorage.shared.lastTrackVisit = previous }
        SessionTemporaryStorage.shared.lastTrackVisit = (source: .push, requestUrl: "https://real.visit")

        let payload = try build(customParams: [
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
    func unencodablePayloadDegradesToEmptyObject() {
        var reported: [String] = []
        let payload = WebViewStartPayloadBuilder(contentId: "content-1",
                                                 operation: nil,
                                                 // Not representable in JSON.
                                                 customParams: ["bad": .double(.nan)],
                                                 insetsSource: nil,
                                                 logError: { reported.append($0) }).build()

        #expect(payload == .string("{}"))
        #expect(reported.count == 1)
    }
}

private enum BuilderTestError: Error {
    case payloadIsNotAString
    case insetsAreNotAnObject
}
