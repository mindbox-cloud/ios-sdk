//
//  MindboxError.swift
//  URLSessionAPIServices
//
//  Created by Yusuf Demirci on 13.04.2020.
//  Copyright © 2020 Yusuf Demirci. All rights reserved.
//

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
    
    init(_ error: InternalError) {
        self = .internalError(error)
    }
}

public struct InternalError: CustomStringConvertible {
    let errorKey: String
    var rawError: Error?
    var statusCode: Int?
    var reason: String?
    var suggestion: String?
    
    init(
        errorKey: String,
        rawError: Error? = nil,
        statusCode: Int? = nil
    ) {
        self.errorKey = errorKey
        self.rawError = rawError
        self.statusCode = statusCode
    }
    
    init(
        errorKey: ErrorKey,
        rawError: Error? = nil,
        statusCode: Int? = nil
    ) {
        self.errorKey = errorKey.rawValue
        self.rawError = rawError
        self.statusCode = statusCode
    }
    
    init(
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
