//
//  LoggerStaticAPITests.swift
//  MindboxLoggerTests
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
@testable import MindboxLogger

/// `Logger`'s static API is a fire-and-forget logging facade: the methods return
/// `Void` and hand a formatted string to `MBLogger.shared`, so there is no value to
/// assert on. These tests drive every input branch of the message builders; the
/// behavioural contract under test is that each shape is formatted and dispatched
/// without trapping.
@Suite("Logger static API", .tags(.loggingAPI))
struct LoggerStaticAPITests {

    @Test("error(LoggerErrorModel) traverses the optional description/status/statusCode branches")
    func errorLoggerModel() {
        Logger.error(LoggerErrorModel(errorType: .server, description: "desc", status: "Failed", statusCode: 500))
        Logger.error(LoggerErrorModel(errorType: .validation))                 // no description/status/statusCode
        Logger.error(LoggerErrorModel(errorType: .connection, status: "x"))     // status only
        Logger.error(LoggerErrorModel(errorType: .unknown, statusCode: 1))      // statusCode only
    }

    @Test("network(request:) renders method, headers and a UTF-8 body")
    func network() {
        var request = URLRequest(url: URL(string: "https://api.mindbox.ru/v3/operations?endpoint=test&device=1")!)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = ["Authorization": "secret", "Accept": "application/json"]
        request.httpBody = #"{"hello":"world"}"#.data(using: .utf8)
        Logger.network(request: request, httpAdditionalHeaders: ["X-Extra": "1"])

        // Minimal request: no method, headers or body.
        Logger.network(request: URLRequest(url: URL(string: "https://api.mindbox.ru")!))
    }

    @Test("network(request:) tolerates a non-UTF8 body")
    func networkNonUTF8Body() {
        var request = URLRequest(url: URL(string: "https://api.mindbox.ru/x")!)
        request.httpMethod = "PUT"
        request.httpBody = Data([0xFF, 0xFE, 0xFA])  // not valid UTF-8 -> "Can't render body"
        Logger.network(request: request)
    }

    @Test("response(data:response:error:) renders success, error and empty variants")
    func response() {
        let url = URL(string: "https://api.mindbox.ru/v3/operations?x=1")!
        let http = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!

        Logger.response(data: #"{"status":"Success"}"#.data(using: .utf8), response: http, error: nil)
        Logger.response(data: nil, response: http, error: NSError(domain: "net", code: -1)) // bumps level to .error
        Logger.response(data: nil, response: nil, error: nil)                               // everything nil
        Logger.response(data: Data([0x00, 0x01]), response: http, error: nil)               // non-JSON body skipped
    }

    @Test("common(message:) logs with and without an explicit subsystem")
    func common() {
        Logger.common(message: "plain message")
        Logger.common(message: "with subsystem", level: .info, category: .database, subsystem: "cloud.Mindbox.Test")
    }

    @Test("deprecated error(MindboxError) traverses every MindboxError case")
    @available(*, deprecated, message: "Intentionally exercises the deprecated Logger.error(_:MindboxError) overload")
    func deprecatedErrorMindboxError() {
        let proto = ProtocolError(status: .protocolError, errorMessage: "m", httpStatusCode: 500, errorId: "id")
        let url = URL(string: "https://api.mindbox.ru")!

        Logger.error(MindboxError.validationError(ValidationError(status: .validationError, validationMessages: [])))
        Logger.error(MindboxError.protocolError(proto))
        Logger.error(MindboxError.serverError(proto))
        Logger.error(MindboxError.internalError(InternalError(errorKey: .general, rawError: NSError(domain: "d", code: 1))))
        Logger.error(MindboxError.internalError(InternalError(errorKey: "no-raw-error")))
        Logger.error(MindboxError.invalidResponse(HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!))
        Logger.error(MindboxError.invalidResponse(nil))   // guard let e else { return }
        Logger.error(MindboxError.connectionError)
        Logger.error(MindboxError.unknown(NSError(domain: "d", code: 2)))
    }
}
