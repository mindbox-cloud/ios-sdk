//
//  MindboxErrorTests.swift
//  MindboxLoggerTests
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
@testable import MindboxLogger

@Suite("MindboxError, InternalError & ErrorKey", .tags(.errorHandling))
struct MindboxErrorTests {

    // MARK: - Fixtures

    /// Minimal `CodingKey` for building `DecodingError` values with a coding path.
    private struct CK: CodingKey {
        let stringValue: String
        let intValue: Int?
        init(stringValue: String) { self.stringValue = stringValue; self.intValue = nil }
        init(intValue: Int) { self.stringValue = "\(intValue)"; self.intValue = intValue }
    }

    private func makeProtocolError(errorId: String? = "err-id") -> ProtocolError {
        ProtocolError(status: .protocolError, errorMessage: "boom", httpStatusCode: 500, errorId: errorId)
    }

    private func makeValidationError() -> ValidationError {
        ValidationError(status: .validationError,
                        validationMessages: [ValidationMessage(message: "msg", location: "loc")])
    }

    private func makeHTTPResponse(_ code: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "https://api.mindbox.ru/x")!,
                        statusCode: code, httpVersion: "HTTP/1.1", headerFields: nil)!
    }

    /// `createJSON()` must always emit parseable JSON; returns the decoded envelope.
    private func envelope(_ error: MindboxError) throws -> [String: Any] {
        let data = try #require(error.createJSON().data(using: .utf8))
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    // MARK: - errorDescription

    @Test("errorDescription routes every case to the right underlying message")
    func errorDescription() {
        let validation = makeValidationError()
        #expect(MindboxError.validationError(validation).errorDescription == validation.description)

        let proto = makeProtocolError()
        #expect(MindboxError.protocolError(proto).errorDescription == proto.description)
        #expect(MindboxError.serverError(proto).errorDescription == proto.description)

        let internalErr = InternalError(errorKey: .general, reason: "r")
        #expect(MindboxError.internalError(internalErr).errorDescription == internalErr.description)

        let underlying = NSError(domain: "d", code: 7)
        #expect(MindboxError.unknown(underlying).errorDescription == underlying.localizedDescription)

        #expect(MindboxError.invalidResponse(makeHTTPResponse(404)).errorDescription?.contains("An invalid response") == true)
        #expect(MindboxError.invalidResponse(nil).errorDescription?.contains("No response") == true)
        #expect(MindboxError.connectionError.errorDescription?.contains("internet connection") == true)
    }

    // MARK: - failureReason

    @Test("failureReason covers every case")
    func failureReason() {
        #expect(MindboxError.serverError(makeProtocolError()).failureReason == "boom")
        #expect(MindboxError.internalError(InternalError(errorKey: .general, reason: "rr")).failureReason == "rr")
        #expect(MindboxError.validationError(makeValidationError()).failureReason == "Validation error")
        #expect(MindboxError.protocolError(makeProtocolError()).failureReason == "boom")
        #expect(MindboxError.unknown(NSError(domain: "d", code: 1)).failureReason == "Unknown error")
        #expect(MindboxError.invalidResponse(nil).failureReason == "Invalid response")
        #expect(MindboxError.connectionError.failureReason == "Connection error")
    }

    // MARK: - errorKey

    @Test("errorKey is only present for internalError")
    func errorKey() {
        #expect(MindboxError.internalError(InternalError(errorKey: "K")).errorKey == "K")
        #expect(MindboxError.connectionError.errorKey == nil)
        #expect(MindboxError.protocolError(makeProtocolError()).errorKey == nil)
    }

    // MARK: - init

    @Test("init(_:) wraps an InternalError")
    func initWrapsInternalError() {
        let error = MindboxError(InternalError(errorKey: "wrapped"))
        #expect(error.errorKey == "wrapped")
        guard case .internalError = error else {
            Issue.record("expected .internalError, got \(error)")
            return
        }
    }

    // MARK: - createJSON

    @Test("createJSON emits valid JSON with the correct envelope type for every case")
    func createJSON() throws {
        #expect(try envelope(.validationError(makeValidationError()))["type"] as? String == "MindboxError")
        #expect(try envelope(.protocolError(makeProtocolError(errorId: nil)))["type"] as? String == "MindboxError")
        #expect(try envelope(.serverError(makeProtocolError()))["type"] as? String == "MindboxError")
        #expect(try envelope(.serverError(makeProtocolError(errorId: nil)))["type"] as? String == "MindboxError")
        #expect(try envelope(.internalError(InternalError(errorKey: "k")))["type"] as? String == "InternalError")
        #expect(try envelope(.internalError(InternalError(errorKey: .general, reason: "r")))["type"] as? String == "InternalError")
        #expect(try envelope(.invalidResponse(makeHTTPResponse(500)))["type"] as? String == "NetworkError")

        let plainResponse = URLResponse(url: URL(string: "https://x")!, mimeType: nil,
                                        expectedContentLength: 0, textEncodingName: nil)
        #expect(try envelope(.invalidResponse(plainResponse))["type"] as? String == "NetworkError")
        #expect(try envelope(.invalidResponse(nil))["type"] as? String == "NetworkError")
        #expect(try envelope(.connectionError)["type"] as? String == "NetworkError")
        #expect(try envelope(.unknown(NSError(domain: "d", code: 1)))["type"] as? String == "InternalError")
    }

    // MARK: - InternalError.description

    @Test("InternalError.description renders DecodingError variants")
    func internalErrorDescriptionDecodingErrors() {
        let typeMismatch = InternalError(
            errorKey: .parsing,
            rawError: DecodingError.typeMismatch(Int.self, .init(codingPath: [CK(stringValue: "field")],
                                                                 debugDescription: "d")))
        #expect(typeMismatch.description.contains("Type Mismatch: key \"field\""))

        let valueNotFound = InternalError(
            errorKey: .parsing,
            rawError: DecodingError.valueNotFound(String.self, .init(codingPath: [], debugDescription: "d")))
        #expect(valueNotFound.description.contains("Value Not Found"))

        let keyNotFound = InternalError(
            errorKey: .parsing,
            rawError: DecodingError.keyNotFound(CK(stringValue: "k"), .init(codingPath: [], debugDescription: "d")))
        #expect(keyNotFound.description.contains("Key Not Found"))

        let dataCorrupted = InternalError(
            errorKey: .parsing,
            rawError: DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "d")))
        #expect(dataCorrupted.description.contains("Data Corrupted"))
    }

    @Test("InternalError.description renders non-decoding errors and optional fields")
    func internalErrorDescriptionFields() {
        let nonDecoding = InternalError(errorKey: .general, rawError: NSError(domain: "x", code: 1))
        #expect(nonDecoding.description.contains("Error description:"))

        let withStatus = InternalError(errorKey: "k", statusCode: 503)
        #expect(withStatus.description.contains("Status code: 503"))

        let withReason = InternalError(errorKey: .general, reason: "why", suggestion: "do this")
        #expect(withReason.description.contains("Reason: why"))
        #expect(withReason.description.contains("Suggestion: do this"))

        let bare = InternalError(errorKey: "only-key")
        #expect(bare.description.contains("Error Key: only-key"))
        #expect(!bare.description.contains("Status code"))
        #expect(!bare.description.contains("Reason"))
    }

    // MARK: - ErrorKey

    @Test(arguments: zip(
        [ErrorKey.general, .parsing, .invalidConfiguration, .unknownStatusKey, .serverError, .invalidAccess, .validation],
        ["Error_general", "Error_parsing", "Invalid_Configuration", "Error_unknown_status_key",
         "Server_error", "Invalid_Access", "Error_validation"]))
    func errorKeyRawValue(_ key: ErrorKey, _ raw: String) {
        #expect(key.rawValue == raw)
    }
}
