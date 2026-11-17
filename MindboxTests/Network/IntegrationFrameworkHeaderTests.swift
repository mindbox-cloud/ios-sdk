//
//  IntegrationFrameworkHeaderTests.swift
//  MindboxTests
//

import Foundation
import Testing
@testable import Mindbox

@Suite("Integration framework header")
struct IntegrationFrameworkHeaderTests {

    private static let headerName = "Mindbox-Integration-Framework"
    private static let xcodeVersion = "9.8.7"
    private static let nativeValue = "native; xcode/9.8.7"
    private static let wrapperValue = "flutter/3.47.8; mindbox-flutter/2.16.0"

    // MARK: - Value

    @Test("Header matches the vector table shared with Android", arguments: [
        (nil, nativeValue),
        ("", nativeValue),
        ("   ", nativeValue),
        (wrapperValue, wrapperValue),
        (String(repeating: "a", count: 128), String(repeating: "a", count: 128)),
        (String(repeating: "a", count: 129), "invalid"),
        ("react-native/0.85.0\nX: y", "invalid"),
        ("флаттер/1.0", "invalid"),
        ("flutter/3.47.8, mindbox-flutter/2.16.0", "invalid"),
        ("native", nativeValue),
        ("invalid", "invalid"),
        ("flutter/3.47.8\n", "invalid"),
        ("flutter/3.47.8\t", "invalid"),
        ("flutter/3.47.8\r\n", "invalid"),
        ("flutter/3.47.8\u{85}", "invalid"),
        ("\n", "invalid"),
        ("\t", "invalid"),
        ("\r\n", "invalid"),
        ("\u{85}", "invalid"),
        ("flutter/3.47.8\0", "invalid"),
        ("a\u{301}", "invalid"),
        ("\u{212A}otlin/2.1.20", "invalid"),
        ("flutter/\u{FF13}.47.8", "invalid")
    ] as [(String?, String)])
    func vectorTable(wrapperValue: String?, expected: String) {
        #expect(IntegrationFrameworkHeader.value(wrapperValue: wrapperValue, xcodeVersion: Self.xcodeVersion) == expected)
    }

    @Test("Every allowed character is sent unchanged")
    func allowedCharactersPass() {
        let value = "ABCxyz019 ._+-/;"

        #expect(IntegrationFrameworkHeader.value(wrapperValue: value, xcodeVersion: Self.xcodeVersion) == value)
    }

    @Test("Xcode part is added only when the wrapper passed nothing")
    func xcodePartOnlyForNative() {
        let fromWrapper = IntegrationFrameworkHeader.value(wrapperValue: Self.wrapperValue, xcodeVersion: Self.xcodeVersion)
        let invalid = IntegrationFrameworkHeader.value(wrapperValue: "bad\nvalue", xcodeVersion: Self.xcodeVersion)

        #expect(fromWrapper == Self.wrapperValue)
        #expect(invalid == "invalid")
    }

    // MARK: - Xcode version

    @Test("Xcode version is read from the DTXcode value of the app", arguments: [
        ("0941", "9.4.1"),
        ("1170", "11.7.0"),
        ("1640", "16.4.0"),
        ("2601", "26.0.1"),
        ("2611", "26.1.1"),
        ("2620", "26.2.0"),
        ("2650", "26.5.0"),
        ("2700", "27.0.0")
    ])
    func xcodeVersionFromDTXcode(rawValue: String, expected: String) {
        #expect(IntegrationFrameworkHeader.xcodeVersion(fromDTXcode: rawValue) == expected)
    }

    @Test("Missing or malformed DTXcode gives unknown")
    func malformedDTXcodeIsUnknown() {
        let malformed: [Any?] = [nil, "", "26", "26.5", "abcd", "26a0", "٢٦٥٠", 2650]

        for rawValue in malformed {
            #expect(IntegrationFrameworkHeader.xcodeVersion(fromDTXcode: rawValue) == "unknown", "DTXcode <\(String(describing: rawValue))>")
        }
    }

    // MARK: - Requests

    @Test("Track visit carries the value passed by a wrapper")
    func trackVisitCarriesWrapperValue() throws {
        let request = try Self.request(.trackVisit, integrationFramework: Self.wrapperValue)

        #expect(request.value(forHTTPHeaderField: Self.headerName) == Self.wrapperValue)
    }

    @Test("Track visit of an app without a wrapper carries native with the Xcode version")
    func trackVisitWithoutWrapperCarriesNative() throws {
        let header = try #require(try Self.request(.trackVisit).value(forHTTPHeaderField: Self.headerName))

        #expect(header.hasPrefix("native; xcode/"))
    }

    @Test("Track visit carries invalid when the stored value is out of the format")
    func trackVisitCarriesInvalid() throws {
        let request = try Self.request(.trackVisit, integrationFramework: "react-native/0.85.0\nX: y")

        #expect(request.value(forHTTPHeaderField: Self.headerName) == "invalid")
    }

    @Test("Only track visit carries the integration framework header", arguments: [
        Event.Operation.installed,
        .installedWithoutCustomer,
        .infoUpdated,
        .keepAlive,
        .trackClick,
        .inAppViewEvent,
        .inAppClickEvent,
        .inAppTargetingEvent,
        .inAppShowFailureEvent,
        .sdkLogs,
        .trackingIdsUpdated,
        .customEvent,
        .syncEvent,
        .trackVisit
    ])
    func onlyTrackVisitCarriesHeader(operation: Event.Operation) throws {
        let request = try Self.request(operation, integrationFramework: Self.wrapperValue)

        #expect(request.value(forHTTPHeaderField: Self.headerName) == Self.expectedHeader(for: operation))
    }

    // MARK: - Helpers

    private static func expectedHeader(for operation: Event.Operation) -> String? {
        switch operation {
        case .trackVisit:
            return wrapperValue
        case .installed, .installedWithoutCustomer, .infoUpdated, .keepAlive, .trackClick,
             .inAppViewEvent, .inAppClickEvent, .inAppTargetingEvent, .inAppShowFailureEvent,
             .sdkLogs, .trackingIdsUpdated, .customEvent, .syncEvent:
            return nil
        }
    }

    private static func request(_ operation: Event.Operation, integrationFramework: String? = nil) throws -> URLRequest {
        let event = Event(type: operation, body: #"{"name":"X","payload":"{}"}"#)
        let wrapper = EventWrapper(
            event: event,
            endpoint: "test-endpoint",
            deviceUUID: "F47AC10B-58CC-4372-A567-0E02B2C3D479",
            integrationFramework: integrationFramework
        )
        return try URLRequestBuilder(domain: "api.mindbox.ru").asURLRequest(route: EventRoute(wrapper))
    }
}
