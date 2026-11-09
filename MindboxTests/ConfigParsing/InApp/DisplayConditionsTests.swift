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

    private func isUnknownType(_ error: CustomDecodingError) -> Bool {
        if case .unknownType = error { return true }
        return false
    }

    @Test("Direct call is the only restrictive value")
    func directCall() throws {
        #expect(try decode(#"{"$type": "directCall"}"#) == .directCall)
    }

    @Test("An unknown or miscased $type is rejected as unknown", arguments: [
        #"{"$type": "pushOnly"}"#,
        #"{"$type": "all"}"#,
        #"{"$type": "DirectCall"}"#
    ])
    func unknownType(value: String) {
        let error = #expect(throws: CustomDecodingError.self) { try decode(value) }
        if let error {
            #expect(isUnknownType(error), "got \(error)")
        }
    }

    @Test("A value without a readable $type is rejected by the decoder", arguments: [
        #"{"$type": 42}"#,
        #"{"$type": null}"#,
        #"{}"#,
        #""directCall""#,
        #"42"#,
        #"[]"#
    ])
    func unreadableValue(value: String) {
        #expect(throws: DecodingError.self) { try decode(value) }
    }

    @Test("An in-app with an unknown condition is dropped")
    func inappWithUnknownType() {
        let error = #expect(throws: CustomDecodingError.self) {
            try decodeInapp(displayConditions: #"{"$type": "unknownCondition"}"#)
        }
        if let error {
            #expect(isUnknownType(error), "got \(error)")
        }
    }

    @Test("An in-app with an unreadable condition is dropped", arguments: [
        #"{}"#,
        #""directCall""#
    ])
    func inappWithUnreadableValue(value: String) {
        #expect(throws: DecodingError.self) { try decodeInapp(displayConditions: value) }
    }

    @Test("A direct-call in-app keeps its condition")
    func inappWithDirectCall() throws {
        #expect(try decodeInapp(displayConditions: #"{"$type": "directCall"}"#).displayConditions == .directCall)
    }

    @Test("A dropped in-app leaves its neighbours in the config")
    func neighboursSurvive() throws {
        func inapp(_ id: String, displayConditions: String) -> String {
            #"{"id": "\#(id)", "sdkVersion": {"min": 1, "max": 1}, "displayConditions": \#(displayConditions), "targeting": {"$type": "true"}, "form": {"variants": []}}"#
        }
        let json = [
            inapp("before", displayConditions: "null"),
            inapp("dropped", displayConditions: #"{"$type": "unknownCondition"}"#),
            inapp("after", displayConditions: #"{"$type": "directCall"}"#)
        ].joined(separator: ",")
        let inapps = try JSONDecoder().decode(FailableDecodableArray<InAppDTO>.self, from: Data("[\(json)]".utf8))
        #expect(inapps.elements.map(\.id) == ["before", "after"])
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
