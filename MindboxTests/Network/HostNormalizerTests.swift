//
//  HostNormalizerTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 4/27/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import Testing
@testable import Mindbox

@Suite("HostNormalizer")
struct HostNormalizerTests {

    // MARK: - extractHost

    @Test("Bare host is returned unchanged")
    func bareHost() {
        #expect(HostNormalizer.extractHost("api.mindbox.ru") == "api.mindbox.ru")
    }

    @Test("https:// prefix is stripped")
    func stripsHttps() {
        #expect(HostNormalizer.extractHost("https://api.mindbox.ru") == "api.mindbox.ru")
    }

    @Test("http:// prefix is stripped")
    func stripsHttp() {
        #expect(HostNormalizer.extractHost("http://api.mindbox.ru") == "api.mindbox.ru")
    }

    @Test("Scheme stripping is case-insensitive")
    func schemeCaseInsensitive() {
        #expect(HostNormalizer.extractHost("HTTPS://api.mindbox.ru") == "api.mindbox.ru")
        #expect(HostNormalizer.extractHost("HtTp://api.mindbox.ru") == "api.mindbox.ru")
    }

    @Test("Trailing slashes are removed")
    func stripsTrailingSlashes() {
        #expect(HostNormalizer.extractHost("api.mindbox.ru/") == "api.mindbox.ru")
        #expect(HostNormalizer.extractHost("api.mindbox.ru///") == "api.mindbox.ru")
    }

    @Test("Whitespace is trimmed")
    func trimsWhitespace() {
        #expect(HostNormalizer.extractHost("  api.mindbox.ru  ") == "api.mindbox.ru")
    }

    @Test("Combined scheme + trailing slash + whitespace")
    func combinedNormalization() {
        #expect(HostNormalizer.extractHost("  https://api.mindbox.ru/  ") == "api.mindbox.ru")
    }

    // MARK: - toBaseURLString

    @Test("Bare host gets https:// prepended")
    func bareHostGetsHttps() {
        #expect(HostNormalizer.toBaseURLString("api.mindbox.ru") == "https://api.mindbox.ru")
    }

    @Test("https:// is preserved")
    func httpsPreserved() {
        #expect(HostNormalizer.toBaseURLString("https://api.mindbox.ru") == "https://api.mindbox.ru")
    }

    @Test("http:// is preserved")
    func httpPreserved() {
        #expect(HostNormalizer.toBaseURLString("http://proxy.example.com") == "http://proxy.example.com")
    }

    @Test("Trailing slash is stripped from base URL")
    func baseURLStripsTrailingSlash() {
        #expect(HostNormalizer.toBaseURLString("https://api.mindbox.ru/") == "https://api.mindbox.ru")
        #expect(HostNormalizer.toBaseURLString("api.mindbox.ru/") == "https://api.mindbox.ru")
    }

    // MARK: - isValidHost

    @Test("Valid bare host passes")
    func validBareHostPasses() {
        #expect(HostNormalizer.isValidHost("api.mindbox.ru"))
    }

    @Test("Valid host with https:// prefix passes")
    func validHostWithSchemePasses() {
        #expect(HostNormalizer.isValidHost("https://api.mindbox.ru"))
        #expect(HostNormalizer.isValidHost("http://proxy.example.com"))
    }

    @Test("Empty input fails")
    func emptyHostFails() {
        #expect(!HostNormalizer.isValidHost(""))
        #expect(!HostNormalizer.isValidHost("   "))
        #expect(!HostNormalizer.isValidHost("https://"))
    }

    @Test("Whitespace inside host fails")
    func whitespaceInsideHostFails() {
        #expect(!HostNormalizer.isValidHost("api mindbox ru"))
    }
}
