//
//  ErrorModel.swift
//  URLSessionAPIServices
//
//  Created by Yusuf Demirci on 13.04.2020.
//  Copyright © 2020 Yusuf Demirci. All rights reserved.
//

enum StatusCode: String, Codable {
    case TransactionAlreadyProcessed
    case Success
    case InternalServerError
    case ProtocolError
    case unknow
    init(from decoder: Decoder) throws {
        let label = try decoder.singleValueContainer().decode(String.self)
        self = StatusCode(rawValue: label) ?? .unknow
    }
}

class ErrorModel: Error {
    
    // MARK: - Properties
    var errorKey: String
    var responseStatusCode: Int?

    var errorMessage: String?
    var rawError: Error?
    var errorId: String?
    var httpStatusCode: Int?
    var status: StatusCode = .unknow
    
    var asMBError: Mindbox.Errors {
        return Mindbox.Errors.other(
            errorDescription: "Network Error with statusCode \(httpStatusCode ?? -1)",
            failureReason: errorMessage, recoverySuggestion: nil
        )
    }

    init( errorKey: String, rawError: Error? = nil) {
        self.errorKey = errorKey
        self.rawError = rawError
    }
}
