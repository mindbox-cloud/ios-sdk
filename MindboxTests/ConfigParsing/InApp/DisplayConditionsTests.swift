//
//  DisplayConditionsTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import Testing
@testable import Mindbox

@Suite("DisplayConditions parsing", .tags(.decoding))
struct DisplayConditionsTests {

    private struct Holder: Decodable {
        let displayConditions: DisplayConditions?
    }

    private func decode(_ value: String) throws -> DisplayConditions? {
        let json = "{\"displayConditions\": \(value)}"
        return try JSONDecoder().decode(Holder.self, from: Data(json.utf8)).displayConditions
    }

    @Test("Direct call is the only restrictive value")
    func directCall() throws {
        #expect(try decode(#"{"$type": "directCall"}"#) == .directCall)
    }

    @Test("Anything unreadable keeps the in-app showing as before", arguments: [
        #"{"$type": "pushOnly"}"#,
        #"{"$type": "all"}"#,
        #"{"$type": "DirectCall"}"#,
        #"{"$type": 42}"#,
        #"{}"#,
        #""directCall""#,
        #"42"#,
        #"[]"#
    ])
    func unreadableValue(value: String) throws {
        #expect(try decode(value) == .unrestricted)
    }

    @Test("Explicit null means showing as before")
    func nullValue() throws {
        #expect(try decode("null") == nil)
    }

    @Test("Missing key means showing as before")
    func missingKey() throws {
        let decoded = try JSONDecoder().decode(Holder.self, from: Data("{}".utf8))
        #expect(decoded.displayConditions == nil)
    }
}
