//
//  DateAndFormatExtensionTests.swift
//  MindboxLoggerTests
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
@testable import MindboxLogger

@Suite("Date / TimeInterval / DateFormat helpers", .tags(.dateFormatting))
struct DateAndFormatExtensionTests {

    private let fixedDate = Date(timeIntervalSince1970: 1_747_017_155)

    @Test("Date.toString() matches HH:mm:ss.SSSS (device time zone, so shape only)")
    func toString() {
        let string = fixedDate.toString()
        #expect(string.range(of: #"^\d{2}:\d{2}:\d{2}\.\d{4}$"#, options: .regularExpression) != nil,
                "unexpected: \(string)")
    }

    @Test("Date.toFullString() matches yyyy-MM-dd'T'HH:mm:ssZ (device time zone, so shape only)")
    func toFullString() {
        let string = fixedDate.toFullString()
        #expect(string.range(of: #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{4}$"#, options: .regularExpression) != nil,
                "unexpected: \(string)")
    }

    @Test("TimeInterval.asReadableDateTime matches yyyy-MM-dd HH:mm:ss.SSS (device time zone, so shape only)")
    func asReadableDateTime() {
        let string = TimeInterval(1_747_017_155).asReadableDateTime
        #expect(string.range(of: #"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}$"#, options: .regularExpression) != nil,
                "unexpected: \(string)")
    }

    @Test("DateFormat.value exposes the literal pattern for every case")
    func dateFormatValue() {
        #expect(DateFormat.allCases.count == 3)
        #expect(DateFormat.api.value == "yyyy-MM-dd'T'HH:mm:ss")
        #expect(DateFormat.utc.value == "yyyy-MM-dd'T'HH:mm:ss'Z'")
        #expect(DateFormat.utcWithMillis.value == "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX")
    }
}
