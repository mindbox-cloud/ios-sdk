//
//  UnknownDecodableTests.swift
//  MindboxLoggerTests
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
@testable import MindboxLogger

@Suite("UnknownDecodable RawRepresentable conformance", .tags(.errorHandling))
struct UnknownDecodableTests {

    private struct StatusWrapper: Decodable { let value: Status }

    private enum NoFallback: String, UnknownCodable {
        case alpha
        case beta
    }
    private struct NoFallbackWrapper: Decodable { let value: NoFallback }

    private func decodeStatus(_ jsonValue: String) throws -> Status {
        try JSONDecoder().decode(StatusWrapper.self, from: Data(#"{"value":\#(jsonValue)}"#.utf8)).value
    }

    private func decodeNoFallback(_ jsonValue: String) throws -> NoFallback {
        try JSONDecoder().decode(NoFallbackWrapper.self, from: Data(#"{"value":\#(jsonValue)}"#.utf8)).value
    }

    @Test("A known raw value decodes to its case")
    func knownValue() throws {
        #expect(try decodeStatus("\"Success\"") == .success)
        #expect(try decodeNoFallback("\"alpha\"") == .alpha)
    }

    @Test("An unknown raw value falls back to .unknown when the type provides one")
    func unknownValueWithFallback() throws {
        #expect(try decodeStatus("\"DefinitelyNotAStatus\"") == .unknown)
    }

    @Test("A non-string payload falls back to .unknown when the type provides one")
    func wrongTypeWithFallback() throws {
        #expect(try decodeStatus("123") == .unknown)
    }

    @Test("An unknown raw value throws .unknownValue when the type has no fallback")
    func unknownValueNoFallback() {
        #expect(throws: UnknownDecodableError.self) {
            _ = try decodeNoFallback("\"gamma\"")
        }
    }

    @Test("A non-string payload rethrows the decoding error when the type has no fallback")
    func wrongTypeNoFallback() {
        #expect(throws: DecodingError.self) {
            _ = try decodeNoFallback("123")
        }
    }
}
