//
//  DateFormatTests.swift
//  MindboxTests
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import Testing
@testable import MindboxLogger

@Suite("DateFormat ISO-8601 primitive", .tags(.dateFormatting))
struct DateFormatTests {

    private let fixedDate = Date(timeIntervalSince1970: 1_747_017_155) // 2025-05-12T02:32:35Z

    @Test("Date.toString(withFormat: .utc) produces literal yyyy-MM-dd'T'HH:mm:ss'Z'")
    func utcFormatLiteral() {
        #expect(fixedDate.toString(withFormat: .utc) == "2025-05-12T02:32:35Z")
    }

    @Test("Date.toString(withFormat: .api) produces literal yyyy-MM-dd'T'HH:mm:ss")
    func apiFormatLiteral() {
        #expect(fixedDate.toString(withFormat: .api) == "2025-05-12T02:32:35")
    }

    @Test("String.toDate(withFormat: .utc) parses canonical UTC literal")
    func utcParseRoundTrip() {
        let parsed = "2025-05-12T02:32:35Z".toDate(withFormat: .utc)
        #expect(parsed == fixedDate)
    }

    @Test("String.toDate(withFormat: .utcWithMillis) parses millisecond-precision payloads")
    func millisParse() {
        let parsed = "2025-05-12T02:32:35.123Z".toDate(withFormat: .utcWithMillis)
        #expect(parsed != nil)
        let expected = Date(timeIntervalSince1970: 1_747_017_155.123)
        if let parsed {
            #expect(abs(parsed.timeIntervalSince(expected)) < 0.001)
        }
    }

    @Test("Formatter does not silently switch to 12h pattern under 12-hour preference")
    func twelveHourPreferenceDoesNotLeakIntoOutput() {
        // QA1480: when the user's region preference is 12h, DateFormatter rewrites
        // HH:mm:ss into h:mm:ss a unless locale is en_US_POSIX. We assert the
        // literal still matches the contract — no AM/PM, no whitespace, leading zero.
        let serialized = fixedDate.toString(withFormat: .utc)
        #expect(!serialized.contains("AM"))
        #expect(!serialized.contains("PM"))
        #expect(!serialized.contains(" "))
        #expect(serialized.hasSuffix("Z"))
        #expect(serialized.count == 20)
    }

    @Test("UTC and millis round-trip via DateTime decoder fallback")
    func roundTripFallbackChain() {
        let withMillis = "2025-05-12T02:32:35.000Z"
        let plain = "2025-05-12T02:32:35Z"
        #expect(plain.toDate(withFormat: .utc) != nil)
        #expect(withMillis.toDate(withFormat: .utc) == nil)
        #expect(withMillis.toDate(withFormat: .utcWithMillis) != nil)
    }
}
