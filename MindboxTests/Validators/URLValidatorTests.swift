//
//  URLValidatorTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 4/27/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import Testing
@testable import Mindbox

@Suite("URLValidator.isValidHost")
struct URLValidatorTests {

    @Test("Common multi-label hosts pass")
    func multiLabelHosts() {
        #expect(URLValidator.isValidHost("api.mindbox.ru"))
        #expect(URLValidator.isValidHost("anonymizer.client.ru"))
        #expect(URLValidator.isValidHost("a.b.c.d.example.com"))
    }

    @Test("Modern TLDs pass (no allow-list)")
    func modernTLDs() {
        #expect(URLValidator.isValidHost("example.app"))
        #expect(URLValidator.isValidHost("example.dev"))
        #expect(URLValidator.isValidHost("example.io"))
        #expect(URLValidator.isValidHost("example.xyz"))
    }

    @Test("Single-label host passes (localhost)")
    func singleLabelHost() {
        #expect(URLValidator.isValidHost("localhost"))
    }

    @Test("Valid IPv4 literals pass")
    func ipv4Literal() {
        #expect(URLValidator.isValidHost("192.168.1.1"))
        #expect(URLValidator.isValidHost("10.0.0.1"))
        #expect(URLValidator.isValidHost("0.0.0.0"))
        #expect(URLValidator.isValidHost("255.255.255.255"))
    }

    @Test("IPv4 octet > 255 fails (parity with Android PatternsCompat)")
    func ipv4OctetOverflowFails() {
        #expect(!URLValidator.isValidHost("999.999.999.999"))
        #expect(!URLValidator.isValidHost("256.0.0.0"))
        #expect(!URLValidator.isValidHost("192.168.1.256"))
    }

    @Test("Three numeric labels are NOT treated as IPv4 — fall through to hostname rules")
    func threeNumericLabelsAreHostname() {
        // 1.2.3 is not IPv4 (3 labels, not 4) and remains structurally a valid hostname.
        #expect(URLValidator.isValidHost("1.2.3"))
    }

    @Test("Five numeric labels are NOT treated as IPv4 — fall through to hostname rules")
    func fiveNumericLabelsAreHostname() {
        // 5 labels of digits are structurally a valid hostname even though not IPv4.
        #expect(URLValidator.isValidHost("1.2.3.4.5"))
    }

    @Test("Hyphens inside labels pass")
    func hyphensInside() {
        #expect(URLValidator.isValidHost("host-with-dash.com"))
        #expect(URLValidator.isValidHost("a-b-c.example.com"))
    }

    @Test("Empty input fails")
    func emptyFails() {
        #expect(!URLValidator.isValidHost(""))
    }

    @Test("Whitespace inside fails")
    func whitespaceFails() {
        #expect(!URLValidator.isValidHost("api mindbox ru"))
        #expect(!URLValidator.isValidHost("\thost\t"))
    }

    @Test("Underscore fails (RFC 1123)")
    func underscoreFails() {
        #expect(!URLValidator.isValidHost("host_name.com"))
    }

    @Test("Leading/trailing hyphen fails")
    func edgeHyphenFails() {
        #expect(!URLValidator.isValidHost("-leading.com"))
        #expect(!URLValidator.isValidHost("trailing-.com"))
    }

    @Test("Empty labels fail")
    func emptyLabelsFail() {
        #expect(!URLValidator.isValidHost(".com"))
        #expect(!URLValidator.isValidHost("api..mindbox.ru"))
        #expect(!URLValidator.isValidHost("api.mindbox.ru."))
    }

    @Test("Embedded scheme fails (caller must strip first)")
    func schemeFails() {
        #expect(!URLValidator.isValidHost("https://api.mindbox.ru"))
    }

    @Test("Path/query in host fails")
    func pathFails() {
        #expect(!URLValidator.isValidHost("api.mindbox.ru/path"))
        #expect(!URLValidator.isValidHost("api.mindbox.ru?q=1"))
    }

    @Test("Total length over 253 fails")
    func tooLongFails() {
        let label = String(repeating: "a", count: 60) // 60 chars per label, well-formed
        let host = (1...5).map { _ in label }.joined(separator: ".") // 5*60 + 4 = 304 chars
        #expect(!URLValidator.isValidHost(host))
    }

    @Test("63-char label is the max accepted")
    func labelLengthBoundary() {
        let valid = String(repeating: "a", count: 63) + ".com"
        #expect(URLValidator.isValidHost(valid))
        let invalid = String(repeating: "a", count: 64) + ".com"
        #expect(!URLValidator.isValidHost(invalid))
    }

    @Test("253-char total length is the max accepted")
    func totalLengthBoundary() {
        // 4 × 63-char labels + 3 dots = 255 → too long
        let label63 = String(repeating: "a", count: 63)
        let invalid = (1...4).map { _ in label63 }.joined(separator: ".")
        #expect(invalid.count == 255)
        #expect(!URLValidator.isValidHost(invalid))

        // 3 × 63-char labels + 1 × 61-char label + 3 dots = 253 → valid
        let label61 = String(repeating: "b", count: 61)
        let valid = [label63, label63, label63, label61].joined(separator: ".")
        #expect(valid.count == 253)
        #expect(URLValidator.isValidHost(valid))
    }

    @Test("Single-character labels pass")
    func singleCharLabels() {
        #expect(URLValidator.isValidHost("a.b"))
        #expect(URLValidator.isValidHost("x.y.z"))
    }

    @Test("Mixed-case hosts pass")
    func mixedCasePasses() {
        #expect(URLValidator.isValidHost("API.Mindbox.RU"))
        #expect(URLValidator.isValidHost("LocalHost"))
    }

    @Test("Punycode IDN host passes (looks like alnum + hyphen)")
    func punycodePasses() {
        #expect(URLValidator.isValidHost("xn--80aswg.xn--p1ai"))
    }

    @Test("Unicode literal IDN host fails (ASCII-only contract)")
    func unicodeLiteralFails() {
        #expect(!URLValidator.isValidHost("мойсайт.рф"))
    }

    @Test("Special characters fail")
    func specialCharsFail() {
        #expect(!URLValidator.isValidHost("host!.com"))
        #expect(!URLValidator.isValidHost("host*.com"))
        #expect(!URLValidator.isValidHost("host%.com"))
        #expect(!URLValidator.isValidHost("host:.com"))
        #expect(!URLValidator.isValidHost("host@.com"))
    }

    @Test("Single label with edge hyphen fails")
    func singleLabelEdgeHyphen() {
        #expect(!URLValidator.isValidHost("-host"))
        #expect(!URLValidator.isValidHost("host-"))
    }

    @Test("Single dot fails")
    func singleDotFails() {
        #expect(!URLValidator.isValidHost("."))
    }
}
