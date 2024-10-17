//
//  MindboxError.swift
//  URLSessionAPIServices
//
//  Created by Yusuf Demirci on 13.04.2020.
//  Copyright © 2020 Yusuf Demirci. All rights reserved.
//

import Foundation
import MindboxLogger

/// Data types that thrown the possible errors from Mindbox.
public enum MindboxError: LocalizedError {
    /// Client error
    case validationError(ValidationError)
    /// Request error/server error
    case protocolError(ProtocolError)
    /// Error for code 5xx
    case serverError(ProtocolError)
    /// Internal mindbox errors wrapper
    case internalError(InternalError)
    /// Other response error
    case invalidResponse(URLResponse?)
    /// Error for connection failure
    case connectionError
    /// Unhandled errors
    case unknown(Error)

    /// Return a formatted error message
    public var errorDescription: String? {
        switch self {
        case let .validationError(error):
            return error.description
        case let .protocolError(error):
            return error.description
        case let .serverError(error):
            return error.description
        case let .unknown(error):
            return error.localizedDescription
        case let .internalError(error):
            return error.description
        case let .invalidResponse(response):
            return "An invalid response was received from the API: " +
                "\(response != nil ? "\(String(describing: response))" : "No response")"
        case .connectionError:
            return "No response received from the server, please check your internet connection."
        }
    }

    public var failureReason: String? {
        switch self {
        case let .serverError(error):
            return error.errorMessage
        case let .internalError(error):
            return error.reason
        case .validationError:
            return "Validation error"
        case let .protocolError(error):
            return error.errorMessage
        case .unknown:
            return "Unknown error"
        case .invalidResponse:
            return "Invalid response"
        case .connectionError:
            return "Connection error"
        }
    }

    public var errorKey: String? {
        switch self {
        case let .internalError(error):
            return error.errorKey
        default:
            return nil
        }
    }

    public init(_ error: InternalError) {
        self = .internalError(error)
    }
}

public extension MindboxError {

    private struct MindboxErrorJSON: Encodable {
        let type: String
        var data = MindboxErrorData()

        struct MindboxErrorData: Encodable {
            var errorId: String?
            var errorKey: String?
            var errorName: String?
            var errorMessage: String?
            var httpStatusCode: String?
            var status: Status?
            var validationMessages: [ValidationMessage]?
        }

        init(errorKey: String, errorName: String, errorMessage: String) {
            self.type = "InternalError"

            data.errorKey = errorKey
            data.errorName = errorName
            data.errorMessage = errorMessage
        }

        init(httpStatusCode: String, errorMessage: String) {
            self.type = "NetworkError"
            data.httpStatusCode = httpStatusCode
            data.errorMessage = errorMessage
        }

        init(status: Status, errorMessage: String, errorId: String, httpStatusCode: Int) {
            self.type = "MindboxError"
            data.status = status
            data.errorMessage = errorMessage
            data.errorId = errorId
            data.httpStatusCode = String(httpStatusCode)
        }

        init(status: Status, validationMessages: [ValidationMessage]) {
            self.type = "MindboxError"
            data.status = status
            data.validationMessages = validationMessages
        }

        func convertToString() -> String {
            guard
                let errorData = try? JSONEncoder().encode(self),
                let errorString = String(data: errorData, encoding: .utf8) else {
                return
                    """
                    {
                        type: "InternalError",
                        data: {
                            errroKey: "\(self.data.errorKey ?? "null")",
                            errroName: "JSON encoding error",
                            errorMessage: "Unable to convert Data to JSON",
                        }
                    }
                    """
            }
            return errorString
        }
    }

    func createJSON() -> String {
        switch self {
        case .validationError(let error):
            return MindboxErrorJSON(status: error.status,
                                    validationMessages: error.validationMessages).convertToString()
        case .protocolError(let error):
            return MindboxErrorJSON(status: error.status,
                                    errorMessage: error.errorMessage,
                                    errorId: error.errorId ?? "",
                                    httpStatusCode: error.httpStatusCode).convertToString()
        case .serverError(let error):
            return MindboxErrorJSON(status: error.status,
                                    errorMessage: error.errorMessage,
                                    errorId: error.errorId ?? "",
                                    httpStatusCode: error.httpStatusCode).convertToString()
        case .internalError(let error):
            return MindboxErrorJSON(errorKey: error.errorKey,
                                    errorName: error.reason ?? "",
                                    errorMessage: error.description).convertToString()
        case .invalidResponse(let response):
            if let httpResponse = response as? HTTPURLResponse {
                let httpStatusCode = String(httpResponse.statusCode)
                let errorMessage = httpResponse.description

                return MindboxErrorJSON(httpStatusCode: httpStatusCode,
                                        errorMessage: errorMessage).convertToString()
            } else {
                return MindboxErrorJSON(httpStatusCode: "null",
                                        errorMessage: "Connection error").convertToString()
            }
        case .connectionError:
            return MindboxErrorJSON(httpStatusCode: "null",
                                    errorMessage: "Connection error").convertToString()
        case .unknown(let error):
            return MindboxErrorJSON(errorKey: "unknown",
                                    errorName: "",
                                    errorMessage: error.localizedDescription).convertToString()
        }
    }
}

public struct InternalError: CustomStringConvertible {
    let errorKey: String
    var rawError: Error?
    var statusCode: Int?
    var reason: String?
    var suggestion: String?

    public init(
        errorKey: String,
        rawError: Error? = nil,
        statusCode: Int? = nil
    ) {
        self.errorKey = errorKey
        self.rawError = rawError
        self.statusCode = statusCode
    }

    public init(
        errorKey: ErrorKey,
        rawError: Error? = nil,
        statusCode: Int? = nil
    ) {
        self.errorKey = errorKey.rawValue
        self.rawError = rawError
        self.statusCode = statusCode
    }

    public init(
        errorKey: ErrorKey,
        reason: String? = nil,
        suggestion: String? = nil
    ) {
        self.errorKey = errorKey.rawValue
        self.reason = reason
        self.suggestion = suggestion
    }

    public var description: String {
        var string: String = ""

        string += "\nError Key: \(errorKey)"

        if let rawError = rawError {
            if let rawError = rawError as? DecodingError {
                switch rawError {
                case let .typeMismatch(_, value):
                    value.codingPath.forEach {
                        string += "\nType Mismatch: key \"\($0.stringValue)\", description: \"\(rawError.localizedDescription)\""
                    }
                case let .valueNotFound(key, value):
                    string += "\nValue Not Found: key - \(key), value - \(value)"
                case let .keyNotFound(key, value):
                    string += "\nKey Not Found: key - \(key), value - \(value)"
                case let .dataCorrupted(key):
                    string += "\nData Corrupted: key - \(key)"
                default:
                    string += "\nError description: \(rawError.localizedDescription)"
                }
            } else {
                string += "\nError description: \(rawError.localizedDescription)"
            }
        }

        if let statusCode = statusCode {
            string += "\nStatus code: \(statusCode)"
        }

        if let reason = reason {
            string += "\nReason: \(reason)"
        }

        if let suggestion = suggestion {
            string += "\nSuggestion: \(suggestion)"
        }

        return string
    }
}

public enum ErrorKey: String {
    case general = "Error_general"
    case parsing = "Error_parsing"
    case invalidConfiguration = "Invalid_Configuration"
    case unknownStatusKey = "Error_unknown_status_key"
    case serverError = "Server_error"
    case invalidAccess = "Invalid_Access"
}

extension MindboxError {
    func asLoggerError() -> LoggerErrorModel {
        switch self {
        case .validationError(let validationError):
            return LoggerErrorModel(errorType: .validation,
                                    description: validationError.description)
        case .protocolError(let protocolError):
            return LoggerErrorModel(errorType: .protocol,
                                    description: "\n[ErrorMessage:] \(protocolError.errorMessage) \n[ErrorId:] \(String(describing: protocolError.errorId))",
                                    status: protocolError.status.rawValue,
                                    statusCode: protocolError.httpStatusCode)
        case .serverError(let serverError):
            return LoggerErrorModel(errorType: .server,
                                    description: serverError.description)
        case .internalError(let internalError):
            return LoggerErrorModel(errorType: .internal,
                                    description: internalError.rawError?.localizedDescription,
                                    errorKey: internalError.errorKey)
        case .invalidResponse(let invalidResponse):
            return LoggerErrorModel(errorType: .invalid,
                                    description: invalidResponse?.description)
        case .connectionError:
            return LoggerErrorModel(errorType: .connection)
        case .unknown(let unknownError):
            return LoggerErrorModel(errorType: .unknown,
                                    description: unknownError.localizedDescription)
        }
    }
}
