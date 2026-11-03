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

    private func decodeInapp(displayConditions: String?) throws -> InAppDTO {
        let field = displayConditions.map { "\"displayConditions\": \($0)," } ?? ""
        let json = """
        {
            "id": "inapp-1",
            "sdkVersion": { "min": 1, "max": 1 },
            \(field)
            "targeting": { "$type": "true" },
            "form": { "variants": [] }
        }
        """
        return try JSONDecoder().decode(InAppDTO.self, from: Data(json.utf8))
    }

    @Test("Direct call is the only restrictive value")
    func directCall() throws {
        #expect(try decode(#"{"$type": "directCall"}"#) == .directCall)
    }

    @Test("Anything unreadable is rejected", arguments: [
        #"{"$type": "pushOnly"}"#,
        #"{"$type": "all"}"#,
        #"{"$type": "DirectCall"}"#,
        #"{"$type": 42}"#,
        #"{}"#,
        #""directCall""#,
        #"42"#,
        #"[]"#
    ])
    func unreadableValue(value: String) {
        #expect(throws: (any Error).self) { try decode(value) }
    }

    @Test("A null value means no conditions")
    func nullValue() throws {
        #expect(try decode("null") == nil)
    }

    @Test("An in-app with an unknown condition is dropped", arguments: [
        #"{"$type": "unknownCondition"}"#,
        #"{"$type": "DirectCall"}"#,
        #"{}"#,
        #""directCall""#
    ])
    func inappWithUnreadableValue(value: String) {
        #expect(throws: (any Error).self) { try decodeInapp(displayConditions: value) }
    }

    @Test("A direct-call in-app keeps its condition")
    func inappWithDirectCall() throws {
        #expect(try decodeInapp(displayConditions: #"{"$type": "directCall"}"#).displayConditions == .directCall)
    }

    @Test("An in-app whose displayConditions is null shows as before")
    func inappWithNullValue() throws {
        #expect(try decodeInapp(displayConditions: "null").displayConditions == .unrestricted)
    }

    @Test("An in-app with no displayConditions key shows as before")
    func inappWithMissingKey() throws {
        #expect(try decodeInapp(displayConditions: nil).displayConditions == .unrestricted)
    }
}
