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

    // MARK: - Failure (.connectionError) → .error with createJSON payload

    @Test("Connection failure becomes .error with MindboxError.createJSON payload")
    func connectionError_becomesError() {
        let outgoing = TransparentView.makeSyncOperationResponse(
            result: .failure(.connectionError),
            action: action,
            id: requestId
        )

        #expect(outgoing.type == .error)
        if case .string(let value) = outgoing.payload {
            #expect(value.contains("NetworkError"), "createJSON for connectionError produces a NetworkError envelope")
            #expect(value.contains("Connection error"))
        } else {
            Issue.record("Expected .string payload")
        }
    }

    // MARK: - Failure (.protocolError) → .error with createJSON payload

    @Test("Protocol error becomes .error with MindboxError.createJSON payload")
    func protocolError_becomesError() {
        let pe = ProtocolError(status: .protocolError, errorMessage: "Bad", httpStatusCode: 400)
        let outgoing = TransparentView.makeSyncOperationResponse(
            result: .failure(.protocolError(pe)),
            action: action,
            id: requestId
        )

        #expect(outgoing.type == .error)
        if case .string(let value) = outgoing.payload {
            #expect(value.contains("MindboxError"))
            #expect(value.contains("ProtocolError"))
        } else {
            Issue.record("Expected .string payload")
        }
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
