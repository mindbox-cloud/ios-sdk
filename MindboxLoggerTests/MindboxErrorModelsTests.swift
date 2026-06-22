//
//  MindboxErrorModelsTests.swift
//  MindboxLoggerTests
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
@testable import MindboxLogger

@Suite("Error & status model types", .tags(.errorHandling))
struct MindboxErrorModelsTests {

    // MARK: - ProtocolError

    @Test("ProtocolError.description includes the errorId when present")
    func protocolErrorDescriptionWithId() {
        let error = ProtocolError(status: .protocolError, errorMessage: "msg", httpStatusCode: 418, errorId: "uuid-1")
        let description = error.description
        #expect(description.contains("Status code: 418"))
        #expect(description.contains("Message: msg"))
        #expect(description.contains("ErrorID: uuid-1"))
    }

    @Test("ProtocolError.description omits the errorId when nil")
    func protocolErrorDescriptionWithoutId() {
        let error = ProtocolError(status: .protocolError, errorMessage: "msg", httpStatusCode: 400, errorId: nil)
        #expect(!error.description.contains("ErrorID"))
    }

    @Test("ProtocolError decodes from JSON, including the optional errorId")
    func protocolErrorDecodes() throws {
        let withId = #"{"httpStatusCode":500,"status":"ProtocolError","errorMessage":"oops","errorId":"id-9"}"#
        let decoded = try JSONDecoder().decode(ProtocolError.self, from: Data(withId.utf8))
        #expect(decoded.httpStatusCode == 500)
        #expect(decoded.status == .protocolError)
        #expect(decoded.errorMessage == "oops")
        #expect(decoded.errorId == "id-9")

        let withoutId = #"{"httpStatusCode":404,"status":"ProtocolError","errorMessage":"nope"}"#
        let noId = try JSONDecoder().decode(ProtocolError.self, from: Data(withoutId.utf8))
        #expect(noId.errorId == nil)
    }

    // MARK: - ValidationError

    @Test("ValidationError.description joins field messages and tolerates nils")
    func validationErrorDescription() {
        let error = ValidationError(status: .validationError, validationMessages: [
            ValidationMessage(message: "Required", location: "email"),
            ValidationMessage(message: nil, location: nil),
        ])
        let description = error.description
        #expect(description.contains("Field email error. Message: Required"))
        #expect(description.contains("Field no location error. Message: no message"))
        #expect(description.contains(";\n"))
    }

    @Test("ValidationError round-trips through Codable")
    func validationErrorCodable() throws {
        let json = #"{"status":"ValidationError","validationMessages":[{"message":"m","location":"l"}]}"#
        let decoded = try JSONDecoder().decode(ValidationError.self, from: Data(json.utf8))
        #expect(decoded.status == .validationError)
        #expect(decoded.validationMessages.count == 1)
        #expect(decoded.validationMessages.first?.location == "l")
        #expect(decoded.validationMessages.first?.message == "m")
    }

    // MARK: - Status

    @Test(arguments: zip(
        [Status.success, .validationError, .protocolError, .internalServerError, .transactionAlreadyProcessed, .unknown],
        ["Success", "ValidationError", "ProtocolError", "InternalServerError", "TransactionAlreadyProcessed", "unknown"]))
    func statusRawValue(_ status: Status, _ raw: String) {
        #expect(status.rawValue == raw)
    }

    // MARK: - LoggerErrorModel / LoggerErrorType

    @Test("LoggerErrorModel stores all fields")
    func loggerErrorModel() {
        let model = LoggerErrorModel(errorType: .server, description: "d", status: "s", statusCode: 500, errorKey: "k")
        #expect(model.errorType == .server)
        #expect(model.description == "d")
        #expect(model.status == "s")
        #expect(model.statusCode == 500)
        #expect(model.errorKey == "k")
    }

    @Test(arguments: zip(
        [LoggerErrorType.validation, .protocol, .server, .internal, .invalid, .connection, .unknown],
        ["validation", "protocol", "server", "internal", "invalid", "connection", "unknown"]))
    func loggerErrorTypeRawValue(_ type: LoggerErrorType, _ raw: String) {
        #expect(type.rawValue == raw)
    }

    // MARK: - SDKLogsStatus

    @Test("SDKLogsStatus.value renders each case")
    func sdkLogsStatusValue() {
        #expect(SDKLogsStatus.ok.value == "OK")
        #expect(SDKLogsStatus.noData.value == "No data found")
        #expect(SDKLogsStatus.elderLog(date: "2025").value == "No data found. The elder log has date: 2025")
        #expect(SDKLogsStatus.latestLog(date: "2026").value == "No data found. The latest log has date: 2026")
        #expect(SDKLogsStatus.largeSize.value == "The requested log size is too large")
    }

    @Test("SDKLogsStatus is Equatable on its associated values")
    func sdkLogsStatusEquatable() {
        #expect(SDKLogsStatus.elderLog(date: "a") == .elderLog(date: "a"))
        #expect(SDKLogsStatus.elderLog(date: "a") != .elderLog(date: "b"))
        #expect(SDKLogsStatus.ok != .noData)
    }
}
