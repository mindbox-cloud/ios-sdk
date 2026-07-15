//
//  TransparentViewSyncOperationResponseTests.swift
//  MindboxTests
//

import Testing
import Foundation
@_spi(Internal) @testable import Mindbox

@Suite("TransparentView.makeSyncOperationResponse")
struct TransparentViewSyncOperationResponseTests {

    private let action = "syncOperation"
    private let requestId = UUID()

    // MARK: - HTTP 200 + ValidationError body → .response with raw body (regression: MOBILE-164)

    @Test("HTTP 200 ValidationError body becomes .response with raw body string")
    func validationErrorBody_becomesResponseWithRawBody() throws {
        let rawBody = #"{"status":"ValidationError","validationMessages":[{"message":"Invalid email","location":"/customer/email"}]}"#
        let data = try #require(rawBody.data(using: .utf8))

        let outgoing = TransparentView.makeSyncOperationResponse(
            result: .success(data),
            action: action,
            id: requestId
        )

        #expect(outgoing.type == .response)
        #expect(outgoing.action == action)
        #expect(outgoing.id == requestId)
        if case .string(let value) = outgoing.payload {
            #expect(value == rawBody, "Payload must be the raw body, not re-serialized")
        } else {
            Issue.record("Expected .string payload, got \(String(describing: outgoing.payload))")
        }
    }

    // MARK: - HTTP 200 + Success body → .response with raw body

    @Test("HTTP 200 Success body becomes .response with raw body string (not re-serialized)")
    func successBody_becomesResponseWithRawBody() throws {
        let rawBody = #"{"status":"Success","customer":{"email":"a@b.c"}}"#
        let data = try #require(rawBody.data(using: .utf8))

        let outgoing = TransparentView.makeSyncOperationResponse(
            result: .success(data),
            action: action,
            id: requestId
        )

        #expect(outgoing.type == .response)
        if case .string(let value) = outgoing.payload {
            #expect(value == rawBody)
        } else {
            Issue.record("Expected .string payload, got \(String(describing: outgoing.payload))")
        }
    }

    // MARK: - HTTP 200 + non-JSON body → .response with raw body string

    @Test("HTTP 200 with non-JSON body still becomes .response (JS decides)")
    func nonJSONBody_becomesResponseWithRawBody() throws {
        let rawBody = "plain text body"
        let data = try #require(rawBody.data(using: .utf8))

        let outgoing = TransparentView.makeSyncOperationResponse(
            result: .success(data),
            action: action,
            id: requestId
        )

        #expect(outgoing.type == .response)
        if case .string(let value) = outgoing.payload {
            #expect(value == rawBody)
        } else {
            Issue.record("Expected .string payload")
        }
    }

    // MARK: - HTTP 200 + empty body → .response with empty string

    @Test("HTTP 200 with empty body becomes .response with empty string payload")
    func emptyBody_becomesResponseWithEmptyString() {
        let outgoing = TransparentView.makeSyncOperationResponse(
            result: .success(Data()),
            action: action,
            id: requestId
        )

        #expect(outgoing.type == .response)
        if case .string(let value) = outgoing.payload {
            #expect(value == "")
        } else {
            Issue.record("Expected .string payload")
        }
    }

    // MARK: - Non-UTF-8 body → .error with explanatory payload

    @Test("Non-UTF-8 body becomes .error with 'Response body is not valid UTF-8'")
    func nonUTF8Body_becomesError() {
        // Bytes that are not valid UTF-8: lone continuation byte 0xC3 + invalid follow-up
        let data = Data([0xC3, 0x28])

        let outgoing = TransparentView.makeSyncOperationResponse(
            result: .success(data),
            action: action,
            id: requestId
        )

        #expect(outgoing.type == .error)
        if case .object(let dict) = outgoing.payload,
           case .string(let errorMessage) = dict["error"] {
            #expect(errorMessage == "Response body is not valid UTF-8")
        } else {
            Issue.record("Expected .object payload with 'error' key, got \(String(describing: outgoing.payload))")
        }
    }

    // MARK: - Failure payloads: data contents only, no {type, data} envelope (MOBILE-197)

    private func decodedErrorPayload(_ outgoing: BridgeMessage) throws -> [String: Any] {
        #expect(outgoing.type == .error)
        var jsonString: String?
        if case .string(let value) = outgoing.payload { jsonString = value }
        let json = try #require(jsonString, "Expected .string payload, got \(String(describing: outgoing.payload))")
        let data = try #require(json.data(using: .utf8))
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["type"] == nil, "Payload must not carry the {type, data} envelope")
        #expect(object["data"] == nil, "Payload must not carry the {type, data} envelope")
        return object
    }

    @Test("Protocol error payload is the data contents: status, errorMessage, httpStatusCode, errorId")
    func protocolError_payloadIsDataContentsOnly() throws {
        let pe = ProtocolError(status: .protocolError, errorMessage: "Operation Test not found", httpStatusCode: 400, errorId: "error-id-1")
        let outgoing = TransparentView.makeSyncOperationResponse(
            result: .failure(.protocolError(pe)),
            action: action,
            id: requestId
        )

        let payload = try decodedErrorPayload(outgoing)
        #expect(payload["status"] as? String == "ProtocolError")
        #expect(payload["errorMessage"] as? String == "Operation Test not found")
        #expect(payload["httpStatusCode"] as? String == "400")
        #expect(payload["errorId"] as? String == "error-id-1")
    }

    @Test("Server error payload is the data contents with InternalServerError status")
    func serverError_payloadIsDataContentsOnly() throws {
        let pe = ProtocolError(status: .internalServerError, errorMessage: "Something went wrong", httpStatusCode: 500)
        let outgoing = TransparentView.makeSyncOperationResponse(
            result: .failure(.serverError(pe)),
            action: action,
            id: requestId
        )

        let payload = try decodedErrorPayload(outgoing)
        #expect(payload["status"] as? String == "InternalServerError")
        #expect(payload["errorMessage"] as? String == "Something went wrong")
        #expect(payload["httpStatusCode"] as? String == "500")
    }

    @Test("Connection failure payload is the data contents without the NetworkError envelope")
    func connectionError_payloadIsDataContentsOnly() throws {
        let outgoing = TransparentView.makeSyncOperationResponse(
            result: .failure(.connectionError),
            action: action,
            id: requestId
        )

        let payload = try decodedErrorPayload(outgoing)
        #expect(payload["httpStatusCode"] as? String == "null")
        #expect(payload["errorMessage"] as? String == "Connection error")
    }

    @Test("Validation error payload is the data contents with validationMessages")
    func validationError_payloadIsDataContentsOnly() throws {
        let ve = ValidationError(
            status: .validationError,
            validationMessages: [ValidationMessage(message: "Invalid email", location: "/customer/email")]
        )
        let outgoing = TransparentView.makeSyncOperationResponse(
            result: .failure(.validationError(ve)),
            action: action,
            id: requestId
        )

        let payload = try decodedErrorPayload(outgoing)
        #expect(payload["status"] as? String == "ValidationError")
        let messages = try #require(payload["validationMessages"] as? [[String: Any]])
        #expect(messages.count == 1)
        #expect(messages.first?["message"] as? String == "Invalid email")
        #expect(messages.first?["location"] as? String == "/customer/email")
    }

    @Test("Internal error payload is the data contents with errorKey")
    func internalError_payloadIsDataContentsOnly() throws {
        let outgoing = TransparentView.makeSyncOperationResponse(
            result: .failure(.internalError(InternalError(errorKey: .parsing, reason: "Broken body"))),
            action: action,
            id: requestId
        )

        let payload = try decodedErrorPayload(outgoing)
        #expect(payload["errorKey"] as? String == "Error_parsing")
        #expect(payload["errorName"] as? String == "Broken body")
    }

    // MARK: - id and action propagated

    @Test("Action and id from the request are preserved on the outgoing message")
    func actionAndIdPreserved() throws {
        let specificAction = "customAction"
        let specificId = UUID()
        let data = try #require("body".data(using: .utf8))

        let outgoing = TransparentView.makeSyncOperationResponse(
            result: .success(data),
            action: specificAction,
            id: specificId
        )

        #expect(outgoing.action == specificAction)
        #expect(outgoing.id == specificId)
    }
}
