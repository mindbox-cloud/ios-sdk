//
//  HapticRequestParserTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 3/18/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
@_spi(Internal) @testable import Mindbox

@Suite("HapticRequestParser", .tags(.webView))
struct HapticRequestParserTests {

    // MARK: - Helpers

    private func makeMessage(jsonPayload: String) -> BridgeMessage {
        BridgeMessage(
            type: .request,
            action: BridgeMessage.Action.haptic,
            payload: .string(jsonPayload)
        )
    }

    private func makeMessage(objectPayload: [String: JSONValue]) -> BridgeMessage {
        BridgeMessage(
            type: .request,
            action: BridgeMessage.Action.haptic,
            payload: .object(objectPayload)
        )
    }

    private func makeMessage(payload: JSONValue?) -> BridgeMessage {
        BridgeMessage(
            type: .request,
            action: BridgeMessage.Action.haptic,
            payload: payload
        )
    }

    // MARK: - Default / missing type

    @Test("nil payload defaults to selection")
    func nilPayload() {
        let result = HapticRequestParser.parse(from: makeMessage(payload: nil))
        #expect(result == .selection)
    }

    @Test("empty JSON object defaults to selection")
    func emptyObject() {
        let result = HapticRequestParser.parse(from: makeMessage(jsonPayload: "{}"))
        #expect(result == .selection)
    }

    @Test("unknown type defaults to selection")
    func unknownType() {
        let result = HapticRequestParser.parse(from: makeMessage(jsonPayload: #"{"type":"unknown"}"#))
        #expect(result == .selection)
    }

    @Test("empty type string defaults to selection")
    func emptyTypeString() {
        let result = HapticRequestParser.parse(from: makeMessage(jsonPayload: #"{"type":""}"#))
        #expect(result == .selection)
    }

    // MARK: - Selection

    @Test("explicit selection type")
    func explicitSelection() {
        let result = HapticRequestParser.parse(from: makeMessage(jsonPayload: #"{"type":"selection"}"#))
        #expect(result == .selection)
    }

    // MARK: - Impact

    @Test("impact without style defaults to medium")
    func impactDefaultStyle() {
        let result = HapticRequestParser.parse(from: makeMessage(jsonPayload: #"{"type":"impact"}"#))
        #expect(result == .impact(.medium))
    }

    @Test("impact with unknown style defaults to medium")
    func impactUnknownStyle() {
        let result = HapticRequestParser.parse(from: makeMessage(jsonPayload: #"{"type":"impact","style":"unknown"}"#))
        #expect(result == .impact(.medium))
    }

    @Test("impact with empty style defaults to medium")
    func impactEmptyStyle() {
        let result = HapticRequestParser.parse(from: makeMessage(jsonPayload: #"{"type":"impact","style":""}"#))
        #expect(result == .impact(.medium))
    }

    @Test(
        "impact parses all styles",
        arguments: HapticRequest.ImpactStyle.allCases
    )
    func impactAllStyles(style: HapticRequest.ImpactStyle) {
        let json = #"{"type":"impact","style":"\#(style.rawValue)"}"#
        let result = HapticRequestParser.parse(from: makeMessage(jsonPayload: json))
        #expect(result == .impact(style))
    }

    // MARK: - Notification

    @Test("notification without style defaults to success")
    func notificationDefaultStyle() {
        let result = HapticRequestParser.parse(from: makeMessage(jsonPayload: #"{"type":"notification"}"#))
        #expect(result == .notification(.success))
    }

    @Test("notification with unknown style defaults to success")
    func notificationUnknownStyle() {
        let result = HapticRequestParser.parse(from: makeMessage(jsonPayload: #"{"type":"notification","style":"unknown"}"#))
        #expect(result == .notification(.success))
    }

    @Test(
        "notification parses all styles",
        arguments: HapticRequest.NotificationStyle.allCases
    )
    func notificationAllStyles(style: HapticRequest.NotificationStyle) {
        let json = #"{"type":"notification","style":"\#(style.rawValue)"}"#
        let result = HapticRequestParser.parse(from: makeMessage(jsonPayload: json))
        #expect(result == .notification(style))
    }

    // MARK: - Pattern

    @Test("pattern with valid events")
    func patternValid() {
        let json = #"{"type":"pattern","pattern":[{"time":0,"duration":100,"intensity":1.0,"sharpness":0.5}]}"#
        let result = HapticRequestParser.parse(from: makeMessage(jsonPayload: json))
        let expected = HapticPatternEvent(time: 0, duration: 100, intensity: 1.0, sharpness: 0.5)
        #expect(result == .pattern([expected]))
    }

    @Test("pattern with missing fields uses defaults")
    func patternDefaults() {
        let json = #"{"type":"pattern","pattern":[{}]}"#
        let result = HapticRequestParser.parse(from: makeMessage(jsonPayload: json))
        let expected = HapticPatternEvent(time: 0, duration: 0, intensity: 1.0, sharpness: 0.5)
        #expect(result == .pattern([expected]))
    }

    @Test("pattern without array returns empty pattern")
    func patternMissingArray() {
        let json = #"{"type":"pattern"}"#
        let result = HapticRequestParser.parse(from: makeMessage(jsonPayload: json))
        #expect(result == .pattern([]))
    }

    @Test("pattern with multiple events")
    func patternMultipleEvents() {
        let json = #"{"type":"pattern","pattern":[{"time":0,"intensity":1.0},{"time":200,"intensity":0.5}]}"#
        let result = HapticRequestParser.parse(from: makeMessage(jsonPayload: json))
        if case .pattern(let events) = result {
            #expect(events.count == 2)
            #expect(events[0].time == 0)
            #expect(events[1].time == 200)
        } else {
            Issue.record("Expected .pattern, got \(result)")
        }
    }

    // MARK: - Object payload (non-string)

    @Test("parses from object payload (not JSON string)")
    func objectPayload() {
        let result = HapticRequestParser.parse(from: makeMessage(objectPayload: [
            "type": .string("impact"),
            "style": .string("heavy")
        ]))
        #expect(result == .impact(.heavy))
    }

    @Test("object payload notification")
    func objectPayloadNotification() {
        let result = HapticRequestParser.parse(from: makeMessage(objectPayload: [
            "type": .string("notification"),
            "style": .string("error")
        ]))
        #expect(result == .notification(.error))
    }
}
