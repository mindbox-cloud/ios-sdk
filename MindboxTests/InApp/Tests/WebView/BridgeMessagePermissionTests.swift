//
//  BridgeMessagePermissionTests.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 16.03.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
@_spi(Internal) @testable import Mindbox

@Suite("BridgeMessage permission.request", .tags(.webView))
struct BridgeMessagePermissionTests {

    // MARK: - deferredActions contract

    @Test("deferredActions contains permissionRequest")
    func deferredActionsContainsPermissionRequest() {
        #expect(BridgeMessage.Action.deferredActions.contains(BridgeMessage.Action.permissionRequest))
    }

    // MARK: - Serialization: Native → JS response

    @Test("Response with granted result encodes payload as JSON string")
    func grantedResponseEncodesCorrectly() throws {
        let id = UUID()
        let message = BridgeMessage(
            type: .response,
            action: BridgeMessage.Action.permissionRequest,
            payload: .object(["result": .string("granted"), "dialogShown": .bool(true)]),
            id: id,
            timestamp: 1_710_340_800_000
        )

        let json = try #require(message.jsonString())
        let data = try #require(json.data(using: .utf8))
        let dict = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        #expect(dict["type"] as? String == "response")
        #expect(dict["action"] as? String == "permission.request")

        let payloadString = try #require(dict["payload"] as? String)
        let payloadData = try #require(payloadString.data(using: .utf8))
        let payloadDict = try #require(
            try JSONSerialization.jsonObject(with: payloadData) as? [String: Any]
        )
        #expect(payloadDict["result"] as? String == "granted")
        #expect(payloadDict["dialogShown"] as? Bool == true)
    }

    @Test("Response with denied result encodes correctly")
    func deniedResponseEncodesCorrectly() throws {
        let id = UUID()
        let message = BridgeMessage(
            type: .response,
            action: BridgeMessage.Action.permissionRequest,
            payload: .object(["result": .string("denied"), "dialogShown": .bool(false)]),
            id: id,
            timestamp: 1_710_340_800_000
        )

        let json = try #require(message.jsonString())
        let data = try #require(json.data(using: .utf8))
        let dict = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        let payloadString = try #require(dict["payload"] as? String)
        let payloadData = try #require(payloadString.data(using: .utf8))
        let payloadDict = try #require(
            try JSONSerialization.jsonObject(with: payloadData) as? [String: Any]
        )
        #expect(payloadDict["result"] as? String == "denied")
        #expect(payloadDict["dialogShown"] as? Bool == false)
    }

    @Test("Error response encodes error message in payload")
    func errorResponseEncodesCorrectly() throws {
        let id = UUID()
        let errorText = "Missing Info.plist key: NSLocationWhenInUseUsageDescription"
        let message = BridgeMessage(
            type: .error,
            action: BridgeMessage.Action.permissionRequest,
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

    @Test("BridgeMessage.from parses permission.request from JS")
    func parsePermissionRequestFromJS() throws {
        let id = UUID()
        let rawJSON = """
        {
            "version": 1,
            "type": "request",
            "action": "permission.request",
            "payload": "{\\"type\\":\\"pushNotifications\\"}",
            "id": "\(id.uuidString.lowercased())",
            "timestamp": 1710340800000
        }
        """

        let message = try #require(BridgeMessage.from(body: rawJSON))

        #expect(message.type == .request)
        #expect(message.parsedAction == .permissionRequest)
        #expect(message.id == id)

        if case .string(let payloadStr) = message.payload {
            let payloadData = try #require(payloadStr.data(using: .utf8))
            let payloadDict = try #require(
                try JSONSerialization.jsonObject(with: payloadData) as? [String: String]
            )
            #expect(payloadDict["type"] == "pushNotifications")
        } else {
            Issue.record("Expected .string payload, got \(String(describing: message.payload))")
        }
    }

    @Test(
        "All permission types parse from JS payload",
        arguments: ["pushNotifications"]
    )
    func parseAllPermissionTypes(typeString: String) throws {
        let id = UUID()
        let rawJSON = """
        {
            "version": 1,
            "type": "request",
            "action": "permission.request",
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
            #expect(PermissionType(rawValue: typeString) != nil)
        } else {
            Issue.record("Expected .string payload, got \(String(describing: message.payload))")
        }
    }
}
