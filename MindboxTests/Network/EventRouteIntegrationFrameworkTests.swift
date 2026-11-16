//
//  EventRouteIntegrationFrameworkTests.swift
//  MindboxTests
//

import Foundation
import Testing
@testable import Mindbox

@Suite("EventRoute integration framework header")
struct EventRouteIntegrationFrameworkTests {

    private static let headerName = "Mindbox-Integration-Framework"

    private static func makeWrapper(
        _ type: Event.Operation,
        integrationFramework: String? = nil,
        bodyJSON: String = "{}"
    ) -> EventWrapper {
        EventWrapper(
            event: Event(type: type, body: bodyJSON),
            endpoint: "test-endpoint",
            deviceUUID: "F47AC10B-58CC-4372-A567-0E02B2C3D479",
            integrationFramework: integrationFramework
        )
    }

    @Test("Visit without value sends native")
    func visitWithoutValue() {
        let route = EventRoute(Self.makeWrapper(.trackVisit))
        #expect(route.headers == [Self.headerName: "native"])
    }

    @Test("Visit with value sends it unchanged")
    func visitWithValue() {
        let value = "flutter/3.47.8; mindbox-flutter/2.16.0"
        let route = EventRoute(Self.makeWrapper(.trackVisit, integrationFramework: value))
        #expect(route.headers == [Self.headerName: value])
    }

    @Test("Visit with bad value sends invalid and the request is still built")
    func visitWithBadValue() throws {
        let route = EventRoute(Self.makeWrapper(.trackVisit, integrationFramework: "bad\nvalue"))
        #expect(route.headers == [Self.headerName: "invalid"])
        let request = try URLRequestBuilder(domain: "api.mindbox.ru").asURLRequest(route: route)
        #expect(request.allHTTPHeaderFields?[Self.headerName] == "invalid")
    }

    @Test("Built visit request contains the header")
    func visitRequestContainsHeader() throws {
        let route = EventRoute(Self.makeWrapper(.trackVisit, integrationFramework: "flutter/3.47.8; mindbox-flutter/2.16.0"))
        let request = try URLRequestBuilder(domain: "api.mindbox.ru").asURLRequest(route: route)
        #expect(request.allHTTPHeaderFields?[Self.headerName] == "flutter/3.47.8; mindbox-flutter/2.16.0")
    }

    @Test("Operations without a header", arguments: [
        (Event.Operation.installed, "sdkOperation"),
        (.infoUpdated, "sdkOperation"),
        (.customEvent, "customAsyncOperation")
    ])
    func otherOperationsHaveNoHeaders(_ type: Event.Operation, _ expectedKind: String) {
        let body = type == .customEvent ? #"{"name":"X","payload":"{}"}"# : "{}"
        let wrapper = Self.makeWrapper(type, integrationFramework: "native", bodyJSON: body)
        switch (wrapper.event.type.request, expectedKind) {
        case (.sdkOperation, "sdkOperation"), (.customAsyncOperation, "customAsyncOperation"):
            break
        default:
            Issue.record("\(type) no longer maps to \(expectedKind)")
        }
        #expect(EventRoute(wrapper).headers == nil)
    }

    @Test("Sync operation keeps only Accept")
    func syncOperationKeepsAccept() {
        let wrapper = Self.makeWrapper(.syncEvent, integrationFramework: "native", bodyJSON: #"{"name":"X","payload":"{}"}"#)
        guard case .customSyncOperation = wrapper.event.type.request else {
            Issue.record("syncEvent no longer maps to customSyncOperation")
            return
        }
        let route = EventRoute(wrapper)
        #expect(route.headers == ["Accept": "application/json"])
    }
}
