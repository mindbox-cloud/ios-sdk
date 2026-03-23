//
//  BridgeMessageOpenSettingsTests.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 23.03.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
@_spi(Internal) @testable import Mindbox

@Suite("BridgeMessage openSettings", .tags(.webView))
struct BridgeMessageOpenSettingsTests {

    // MARK: - deferredActions contract

    @Test("deferredActions contains openSettings")
    func deferredActionsContainsOpenSettings() {
        #expect(BridgeMessage.Action.deferredActions.contains(BridgeMessage.Action.openSettings))
    }

    // MARK: - Serialization: Native → JS response

    @Test("Success response for notifications type encodes payload as JSON string")
    func notificationsSuccessResponseEncodesCorrectly() throws {
        let id = UUID()
        let message = BridgeMessage(
            type: .response,
            action: BridgeMessage.Action.openSettings,
            payload: .object(["success": .bool(true)]),
            id: id,
            timestamp: 1_710_340_800_000
        )

        let json = try #require(message.jsonString())
        let data = try #require(json.data(using: .utf8))
        let dict = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        #expect(dict["type"] as? String == "response")
        #expect(dict["action"] as? String == "openSettings")

        let payloadString = try #require(dict["payload"] as? String)
        let payloadData = try #require(payloadString.data(using: .utf8))
        let payloadDict = try #require(
            try JSONSerialization.jsonObject(with: payloadData) as? [String: Any]
        )
        #expect(payloadDict["success"] as? Bool == true)
    }

    @Test("Error response encodes error message in payload")
    func errorResponseEncodesCorrectly() throws {
        let id = UUID()
        let errorText = "Unknown settings type: 'invalid'"
        let message = BridgeMessage(
            type: .error,
            action: BridgeMessage.Action.openSettings,
            payload: .object(["error": .string(errorText)]),
            id: id,
            timestamp: 1_710_340_800_000
        )

        let json = try #require(message.jsonString())
        let data = try #require(json.data(using: .utf8))
        let dict = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        #expect(dict["type"] as? String == "error")

        let payloadString = try #require(dict["payload"] as? String)
        let payloadData = try #require(payloadString.data(using: .utf8))
        let payloadDict = try #require(
            try JSONSerialization.jsonObject(with: payloadData) as? [String: String]
        )
        #expect(payloadDict["error"] == errorText)
    }

    // MARK: - Deserialization: JS → Native request

    @Test("BridgeMessage.from parses openSettings with notifications type from JS")
    func parseOpenSettingsNotificationsFromJS() throws {
        let id = UUID()
        let rawJSON = """
        {
            "version": 1,
            "type": "request",
            "action": "openSettings",
            "payload": "{\\"type\\":\\"notifications\\"}",
            "id": "\(id.uuidString.lowercased())",
            "timestamp": 1710340800000
        }
        """

        let message = try #require(BridgeMessage.from(body: rawJSON))

        #expect(message.type == .request)
        #expect(message.action == BridgeMessage.Action.openSettings)
        #expect(message.id == id)

        if case .string(let payloadStr) = message.payload {
            let payloadData = try #require(payloadStr.data(using: .utf8))
            let payloadDict = try #require(
                try JSONSerialization.jsonObject(with: payloadData) as? [String: String]
            )
            #expect(payloadDict["type"] == "notifications")
        } else {
            Issue.record("Expected .string payload, got \(String(describing: message.payload))")
        }
    }

    @Test("BridgeMessage.from parses openSettings with application type from JS")
    func parseOpenSettingsApplicationFromJS() throws {
        let id = UUID()
        let rawJSON = """
        {
            "version": 1,
            "type": "request",
            "action": "openSettings",
            "payload": "{\\"type\\":\\"application\\"}",
            "id": "\(id.uuidString.lowercased())",
            "timestamp": 1710340800000
        }
        """

        let message = try #require(BridgeMessage.from(body: rawJSON))

        #expect(message.type == .request)
        #expect(message.action == BridgeMessage.Action.openSettings)

        if case .string(let payloadStr) = message.payload {
            let payloadData = try #require(payloadStr.data(using: .utf8))
            let payloadDict = try #require(
                try JSONSerialization.jsonObject(with: payloadData) as? [String: String]
            )
            #expect(payloadDict["type"] == "application")
        } else {
            Issue.record("Expected .string payload, got \(String(describing: message.payload))")
        }
    }

    @Test(
        "All valid settings types parse from JS payload",
        arguments: ["notifications", "application"]
    )
    func parseAllValidSettingsTypes(typeString: String) throws {
        let id = UUID()
        let rawJSON = """
        {
            "version": 1,
            "type": "request",
            "action": "openSettings",
            "payload": "{\\"type\\":\\"\(typeString)\\"}",
            "id": "\(id.uuidString.lowercased())",
            "timestamp": 1710340800000
        }
        """

        let message = try #require(BridgeMessage.from(body: rawJSON))

        if case .string(let payloadStr) = message.payload {
            let payloadData = try #require(payloadStr.data(using: .utf8))
            let payloadDict = try #require(
                try JSONSerialization.jsonObject(with: payloadData) as? [String: String]
            )
            #expect(payloadDict["type"] == typeString)
        } else {
            Issue.record("Expected .string payload, got \(String(describing: message.payload))")
        }
    }
}
