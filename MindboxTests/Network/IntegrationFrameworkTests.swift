//
//  IntegrationFrameworkTests.swift
//  MindboxTests
//

import Foundation
import Testing
@testable import Mindbox

@Suite("IntegrationFramework header value")
struct IntegrationFrameworkTests {

    @Test("Header name")
    func headerName() {
        #expect(IntegrationFramework.headerName == "Mindbox-Integration-Framework")
    }

    @Test("Missing value gives native")
    func nilGivesNative() {
        #expect(IntegrationFramework.headerValue(for: nil) == "native")
    }

    @Test("Valid values pass unchanged", arguments: [
        "react-native/0.85.0; expo/55.0.0; mindbox-react-native/2.16.0",
        "flutter/3.47.8; mindbox-flutter/2.16.0",
        "flutter/unknown; mindbox-flutter/2.16.0",
        "native",
        "A z 0 9 . _ + - / ;",
        String(repeating: "a", count: 128)
    ])
    func validValuesUnchanged(_ value: String) {
        #expect(IntegrationFramework.headerValue(for: value) == value)
    }

    @Test("Invalid values give invalid", arguments: [
        "",
        String(repeating: "a", count: 129),
        "a\nb", "a\rb", "a\tb", "a:b", "a,b", "a\"b", "a{b", "a(b", "a@b",
        "\u{0436}", "caf\u{00E9}", "\u{0663}", "a\u{1F600}"
    ])
    func invalidValues(_ value: String) {
        #expect(IntegrationFramework.headerValue(for: value) == "invalid")
    }
}
